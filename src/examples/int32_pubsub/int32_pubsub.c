#include "transport_common.h"
#include <std_msgs/msg/int32.h>

#define MAX_MESSAGES 1000

static rclc_support_t       support;
static rcl_allocator_t      allocator;
static rcl_node_t           node;
static rcl_publisher_t      publisher;
static rcl_subscription_t   subscriber;
static rclc_executor_t      executor;
static std_msgs__msg__Int32 outgoingMsg, incomingMsg;
static int msgCount = 0;

static void echo_callback(const void *msgin)
{
	const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

	msgCount++;
	microkit_dbg_puts("RECEIVED\n");

	if (msgCount >= MAX_MESSAGES)
		return;

	outgoingMsg.data = msg->data + 1;
	rcl_ret_t ret = rcl_publish(&publisher, (const void *)&outgoingMsg, NULL);
	if (ret == RCL_RET_OK)
		microkit_dbg_puts("SENT\n");
}

static void ros_setup(void)
{
	allocator = rcl_get_default_allocator();
	RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));
	RCCHECK(rclc_node_init_default(&node, "int32_pubsub_node", "", &support));

	RCCHECK(rclc_publisher_init_best_effort(&publisher, &node,
	          ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32), "/int32_echo"));
	RCCHECK(rclc_subscription_init_best_effort(&subscriber, &node,
	          ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32), "/int32_echo"));

	executor = rclc_executor_get_zero_initialized_executor();
	RCCHECK(rclc_executor_init(&executor, &support.context, 1, &allocator));
	RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &incomingMsg,
	                                       echo_callback, ON_NEW_DATA));

	outgoingMsg.data = 0;
	msgCount = 0;
	microkit_dbg_puts("int32_pubsub: initialized\n");
}

void notified(microkit_channel ch)
{
	switch (ch) {
	case CHAN_READY: {
		transport_networking_init();
		transport_rmw_init();
		ros_setup();
		rcl_ret_t _rc = rcl_publish(&publisher, (const void *)&outgoingMsg, NULL);
		_rc == RCL_RET_OK ? microkit_dbg_puts("SENT\n") : microkit_dbg_puts("SENT_FAIL\n");
		break;
	}
	case CHAN_PINGPONG: {
		if (!transport_is_ready()) break;
		rclc_executor_spin_some(&executor, 0);
		break;
	}
	default:
		break;
	}
}
