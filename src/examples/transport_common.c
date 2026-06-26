#include "transport_common.h"

char *pd2vmm, *vmm2pd;
spsc_queue_t *spsc_pd2vmm, *spsc_vmm2pd;
struct ethhdr txEthHdr;
struct iphdr  txIpHdr;
struct udphdr txUdpHdr;

static bool transportReady = false;

void heap_init(void);

void init(void)
{
	heap_init();
}

bool custom_transport_seL4_open(uxrCustomTransport *t)
{
	(void)t;
	return true;
}

bool custom_transport_seL4_close(uxrCustomTransport *t)
{
	(void)t;
	return true;
}

static bool is_addressed_to_me(const char *pkt)
{
	const struct ethhdr *ethHdr = (const struct ethhdr *)pkt;
	const struct iphdr *ipHdr = (const struct iphdr *)(ethHdr + 1);
	const struct udphdr *udpHdr = (const struct udphdr *)(ipHdr + 1);

	if (memcmp(ethHdr->h_dest, txEthHdr.h_source, 6) != 0)
		return false;
	if (ethHdr->h_proto != htons(ETH_P_IP))
		return false;
	if (ipHdr->daddr != txIpHdr.saddr)
		return false;
	if (ipHdr->protocol != IPPROTO_UDP)
		return false;
	if (udpHdr->uh_dport != txUdpHdr.uh_sport)
		return false;

	return true;
}

size_t custom_transport_seL4_write(uxrCustomTransport *t, const uint8_t *buf,
                                   size_t len, uint8_t *errcode)
{
	(void)t;
	(void)errcode;
	if (len > 1500) {
		microkit_dbg_puts("len > 1500\n");
		return 0;
	}
	char *txBuf = spsc_new_block(spsc_pd2vmm);
	make_pkt(txBuf, 2048, (const char *)buf, len,
	         &txEthHdr, &txIpHdr, &txUdpHdr);
	spsc_push(spsc_pd2vmm);
	microkit_notify(CHAN_PINGPONG);
	return len;
}

size_t custom_transport_seL4_read(uxrCustomTransport *t, uint8_t *buf,
                                  size_t len, int timeout, uint8_t *errcode)
{
	(void)t;
	(void)timeout;
	(void)errcode;

	char *rxPkt;
	while ((rxPkt = spsc_front_block(spsc_vmm2pd))) {
		if (is_addressed_to_me(rxPkt))
			break;
		spsc_pop(spsc_vmm2pd);
	}
	char *payload = get_payload(rxPkt);
	size_t payloadLen = get_payload_len(rxPkt);

	if (len < payloadLen) {
		spsc_pop(spsc_vmm2pd);
		return 0;
	}
	memcpy(buf, payload, payloadLen);
	spsc_pop(spsc_vmm2pd);
	return payloadLen;
}

void transport_networking_init(void)
{
	spsc_pd2vmm = (spsc_queue_t *)pd2vmm;
	if (!spsc_init(spsc_pd2vmm,
	               pd2vmm + sizeof(spsc_queue_t),
	               pd2vmm + PD2VMM_SIZE, 11)) {
		microkit_dbg_puts("transport: spsc_init pd2vmm FAILED\n");
		return;
	}
	spsc_vmm2pd = (spsc_queue_t *)vmm2pd;
	if (!spsc_init(spsc_vmm2pd,
	               vmm2pd + sizeof(spsc_queue_t),
	               vmm2pd + VMM2PD_SIZE, 11)) {
		microkit_dbg_puts("transport: spsc_init vmm2pd FAILED\n");
		return;
	}

	txEthHdr = make_ethhdr(TX_MAC_SRC, TX_MAC_DST);
	txIpHdr  = make_iphdr(TX_IP_SRC, TX_IP_DST);
	txUdpHdr = make_udphdr(TX_UDP_SPORT, TX_UDP_DPORT);

	transportReady = true;
}

void transport_rmw_init(void)
{
	rmw_ret_t rmw_ret = rmw_uros_set_custom_transport(
		false,
		NULL,
		custom_transport_seL4_open,
		custom_transport_seL4_close,
		custom_transport_seL4_write,
		custom_transport_seL4_read);

	if (rmw_ret != RMW_RET_OK) {
		microkit_dbg_puts("ERROR: rmw_uros_set_custom_transport failed\n");
		transportReady = false;
	}
}

bool transport_is_ready(void)
{
	return transportReady;
}
