#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <microkit.h>
#include <libvmm/libvmm.h>
#include <sddf/network/queue.h>
#include <sddf/network/constants.h>
#include "utils/spsc_queue.h"
#include "utils/networking.h"

#if defined(BOARD_qemu_virt_aarch64)
#define GUEST_RAM_START_GPA 0x40000000
#define GUEST_DTB_VADDR 0x4f000000
#define GUEST_INIT_RAM_DISK_VADDR 0x4d700000
#define GUEST_RAM_SIZE 0x10000000
#else
#error Need to define VM image address and DTB address
#endif

#define VIRTIO_NET_MMIO_BASE    0xC100000
#define VIRTIO_NET_MMIO_SIZE    0x200
#define VIRTIO_NET_VIRQ         40

#define NET_NUM_BUFFERS         16
#define NET_BUF_SIZE            2048

#define VM_MAC_ADDR            { 0x02, 0x00, 0x00, 0x00, 0x00, 0x01 }
#define CHAN_PINGPONG           2
#define CHAN_READY              1

#define READY_SIGNAL_MMIO_BASE  0xC200000
#define READY_SIGNAL_MMIO_SIZE  0x1000

#define PKT_SIZE 2048
#define PD2VMM_SIZE 0x100000
#define VMM2PD_SIZE 0x100000

extern char _guest_kernel_image[], _guest_kernel_image_end[];
extern char _guest_dtb_image[], _guest_dtb_image_end[];
extern char _guest_initrd_image[], _guest_initrd_image_end[];

char *pd2vmm, *vmm2pd;
spsc_queue_t *spsc_pd2vmm, *spsc_vmm2pd;
uintptr_t guestRam;
struct network_ctx_t *networkCtx;
static struct virtio_net_device virtio_net;
static net_queue_handle_t net_rx, net_tx;

typedef struct network_ctx_t {
    struct {
        net_queue_t q;
        net_buff_desc_t bufs[NET_NUM_BUFFERS];
    } tx_free;
    struct {
        net_queue_t q;
        net_buff_desc_t bufs[NET_NUM_BUFFERS];
    } tx_active;
    struct {
        net_queue_t q;
        net_buff_desc_t bufs[NET_NUM_BUFFERS];
    } rx_free;
    struct {
        net_queue_t q;
        net_buff_desc_t bufs[NET_NUM_BUFFERS];
    } rx_active;
    uint8_t tx_data[NET_NUM_BUFFERS * NET_BUF_SIZE] __attribute__((aligned(64)));
    uint8_t rx_data[NET_NUM_BUFFERS * NET_BUF_SIZE] __attribute__((aligned(64)));
} network_ctx_t;

static volatile bool portOpenSignal = false;
static bool ready_signal_handler(size_t vcpu_id, size_t offset, size_t fsr, seL4_UserContext *regs, void *data)
{
    if (fault_is_write(fsr) && !portOpenSignal) {
        portOpenSignal = true;
        LOG_VMM("Guest signaled readiness, notifying ping_pong PD\n");
        microkit_notify(CHAN_READY);
    }
    return true;
}

static void process_tx_pending(void)
{
    net_buff_desc_t buf;
    while (net_dequeue_active(&net_tx, &buf) != -1) {
        uint8_t *pkt = networkCtx->tx_data + buf.io_or_offset;
        uint32_t len = buf.len;
        char *newBlock = spsc_new_block(spsc_vmm2pd);
        memcpy(newBlock, pkt, len);

        spsc_push(spsc_vmm2pd);
        net_enqueue_free(&net_tx, buf);
        if (portOpenSignal)
            microkit_notify(CHAN_PINGPONG);
    }
}

static void send_pkt_to_guest()
{
    char *pkt = spsc_front_block(spsc_pd2vmm);
    net_buff_desc_t buf;
    net_dequeue_free(&net_rx, &buf);

    /* Derive actual packet length from the Ethernet+IP headers to avoid
     * sending trailing SPSC-block garbage (up to PKT_SIZE) to the guest.
     * The raw frame from make_pkt() always uses IPv4 (ETH_P_IP). */
    uint32_t pkt_len = PKT_SIZE;  // fallback
    if (pkt[12] == 0x08 && pkt[13] == 0x00) {  // EtherType == IPv4
        uint16_t ip_tot_len = ((uint8_t)pkt[16] << 8) | (uint8_t)pkt[17];
        pkt_len = 14 + ip_tot_len;  // Ethernet header (14) + IP total length
        if (pkt_len > PKT_SIZE) pkt_len = PKT_SIZE;  // safety clamp
    }
    memcpy(networkCtx->rx_data + buf.io_or_offset, pkt, pkt_len);
    buf.len = pkt_len;
    
    net_enqueue_active(&net_rx, buf);
    virtio_net_handle_rx(&virtio_net);
    spsc_pop(spsc_pd2vmm);
}

void init(void)
{
    spsc_pd2vmm = (spsc_queue_t *)pd2vmm;
    if (!spsc_init(spsc_pd2vmm, pd2vmm + sizeof(spsc_queue_t), pd2vmm + PD2VMM_SIZE, 11)) {
        LOG_VMM_ERR("spsc_init pd2vmm failed\n");
        return;
    }
    spsc_vmm2pd = (spsc_queue_t *)vmm2pd;
    if (!spsc_init(spsc_vmm2pd, vmm2pd + sizeof(spsc_queue_t), vmm2pd + VMM2PD_SIZE, 11)) {
        LOG_VMM_ERR("spsc_init vmm2pd failed\n");
        return;
    }

    memset((void *)networkCtx, 0, sizeof(struct network_ctx_t));
    net_queue_init(&net_tx, &networkCtx->tx_free.q, &networkCtx->tx_active.q, NET_NUM_BUFFERS);
    net_cancel_signal_active(&net_tx);
    net_queue_init(&net_rx, &networkCtx->rx_free.q, &networkCtx->rx_active.q, NET_NUM_BUFFERS);

    for (uint32_t i = 0; i < NET_NUM_BUFFERS; i++) {
        net_buff_desc_t b = { .io_or_offset = i * NET_BUF_SIZE, .len = 0 };
        net_enqueue_free(&net_tx, b);
    }
    for (uint32_t i = 0; i < NET_NUM_BUFFERS; i++) {
        net_buff_desc_t b = { .io_or_offset = i * NET_BUF_SIZE, .len = 0 };
        net_enqueue_free(&net_rx, b);
    }

    arch_guest_init_t args = {
        .num_vcpus = 1,
        .num_guest_ram_regions = 1,
        .guest_ram_regions = { (struct guest_ram_region) {
            .gpa_start = GUEST_RAM_START_GPA,
            .size = GUEST_RAM_SIZE,
            .vmm_vaddr = (void *)guestRam
        } }
    };
    if (!guest_init(args)) {
        LOG_VMM_ERR("Failed to initialise guest\n");
        return;
    }

    size_t kernel_size = _guest_kernel_image_end - _guest_kernel_image;
    size_t dtb_size = _guest_dtb_image_end - _guest_dtb_image;
    size_t initrd_size = _guest_initrd_image_end - _guest_initrd_image;
    uintptr_t kernel_pc = linux_setup_images(GUEST_RAM_START_GPA,
                                             (uintptr_t)_guest_kernel_image, kernel_size,
                                             (uintptr_t)_guest_dtb_image, GUEST_DTB_VADDR, dtb_size,
                                             (uintptr_t)_guest_initrd_image, GUEST_INIT_RAM_DISK_VADDR, initrd_size);
    if (!kernel_pc) {
        LOG_VMM_ERR("Failed to initialise guest images\n");
        return;
    }

    uint8_t vm_mac[6] = VM_MAC_ADDR;
    if (!virtio_mmio_net_init(&virtio_net,
                                     VIRTIO_NET_MMIO_BASE,
                                     VIRTIO_NET_MMIO_SIZE,
                                     VIRTIO_NET_VIRQ,
                                     &net_rx,
                                     &net_tx,
                                     (uintptr_t)networkCtx->rx_data,
                                     (uintptr_t)networkCtx->tx_data,
                                     CHAN_PINGPONG,
                                     CHAN_PINGPONG,
                                     vm_mac)) 
    {
        LOG_VMM_ERR("Failed to initialise virtIO-networkCtx device\n");
        return;
    }

    if (!fault_register_vm_exception_handler(READY_SIGNAL_MMIO_BASE,
                                             READY_SIGNAL_MMIO_SIZE,
                                             ready_signal_handler,
                                             NULL))
    {
        LOG_VMM_ERR("Failed to register readiness signal handler\n");
        return;
    }

    guest_start(kernel_pc, GUEST_DTB_VADDR, GUEST_INIT_RAM_DISK_VADDR);
}

void notified(microkit_channel ch)
{
    switch (ch) {
    case CHAN_PINGPONG:
        while (!spsc_empty(spsc_pd2vmm)) send_pkt_to_guest();
        break;
    default:
        LOG_VMM_ERR("Unexpected notification on channel: 0x%lx\n", ch);
        break;
    }
}

seL4_Bool fault(microkit_child child, microkit_msginfo msginfo, microkit_msginfo *reply_msginfo)
{
    bool success = fault_handle(child, msginfo);
    if (success) {
        if(portOpenSignal) {
            process_tx_pending();
            *reply_msginfo = microkit_msginfo_new(0, 0);
        }
        return seL4_True;
    }

    LOG_VMM_ERR("Failed to handle fault, stopping guest\n");
    microkit_vcpu_stop(child);
    return seL4_False;
}
