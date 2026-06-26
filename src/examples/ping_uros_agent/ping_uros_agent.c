#include "transport_common.h"
#include <rmw_microros/rmw_microros.h>

static void ros_ping(void)
{
	rmw_ret_t ret = rmw_uros_ping_agent(1000, 5);
	if (ret == RMW_RET_OK)
		microkit_dbg_puts("AGENT_UP\n");
	else
		microkit_dbg_puts("AGENT_DOWN\n");
}

void notified(microkit_channel ch)
{
	switch (ch) {
	case CHAN_READY: {
		transport_networking_init();
		transport_rmw_init();
		ros_ping();
		break;
	}
	default:
		break;
	}
}
