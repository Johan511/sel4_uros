#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <microkit.h>

#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>
#include <rmw_microros/custom_transport.h>

#include "utils/spsc_queue.h"
#include "utils/networking.h"

#define CHAN_READY        1
#define CHAN_PINGPONG     2
#define PD2VMM_SIZE       0x100000
#define VMM2PD_SIZE       0x100000
#define TX_IP_SRC         "10.0.2.100"
#define TX_IP_DST         "10.0.2.15"
#define TX_MAC_SRC        "02:00:00:00:00:02"
#define TX_MAC_DST        "02:00:00:00:00:01"
#define TX_UDP_SPORT      7400
#define TX_UDP_DPORT      8888

#define RCCHECK(fn) do {                               \
    rcl_ret_t _rc = (fn);                              \
    if (_rc != RCL_RET_OK) {                           \
        microkit_dbg_puts("RCCHECK FAILED: " #fn "\n"); \
        return;                                        \
    }                                                  \
} while(0)

extern char *pd2vmm, *vmm2pd;
extern spsc_queue_t *spsc_pd2vmm, *spsc_vmm2pd;
extern struct ethhdr txEthHdr;
extern struct iphdr  txIpHdr;
extern struct udphdr txUdpHdr;

bool   custom_transport_seL4_open(uxrCustomTransport *t);
bool   custom_transport_seL4_close(uxrCustomTransport *t);
size_t custom_transport_seL4_write(uxrCustomTransport *t, const uint8_t *buf,
                                   size_t len, uint8_t *errcode);
size_t custom_transport_seL4_read(uxrCustomTransport *t, uint8_t *buf,
                                  size_t len, int timeout, uint8_t *errcode);

void transport_networking_init(void);
void transport_rmw_init(void);
bool transport_is_ready(void);

void heap_init(void);
void init(void);
