#include "transport_common.h"
#include <std_msgs/msg/header.h>

#define DEVICE_ID       0
#define MAX_PINGS_SENT  1000

static rclc_support_t       support;
static rcl_allocator_t      allocator;
static rcl_node_t           node;
static rcl_publisher_t      pingPublisher, pongPublisher;
static rcl_subscription_t   pingSubscriber, pongSubscriber;
static rclc_executor_t      executor;
static std_msgs__msg__Header incomingPing, incomingPong, outgoingPing, outgoingPong;
static int seqNum = 0;

static void send_impl(std_msgs__msg__Header *hdr, rcl_publisher_t *publisher);

static void send_ping(const void *)
{
	static uint64_t numPingsSent = 0;
	if (++numPingsSent > MAX_PINGS_SENT)
		return;
	send_impl(&outgoingPing, &pingPublisher);
	microkit_dbg_puts("sent_ping\n");
}

static void send_pong(const void *)
{
	send_impl(&outgoingPong, &pongPublisher);
	microkit_dbg_puts("sent_pong\n");
}

static void ros_setup(void)
{
	std_msgs__msg__Header__init(&incomingPing);
	std_msgs__msg__Header__init(&incomingPong);
	std_msgs__msg__Header__init(&outgoingPing);
	std_msgs__msg__Header__init(&outgoingPong);

	allocator = rcl_get_default_allocator();
	RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));
	RCCHECK(rclc_node_init_default(&node, "pingpong_node", "", &support));

	RCCHECK(rclc_publisher_init_best_effort(&pingPublisher, &node,
	          ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Header), "/microROS/ping"));
	RCCHECK(rclc_publisher_init_best_effort(&pongPublisher, &node,
	          ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Header), "/microROS/pong"));

	RCCHECK(rclc_subscription_init_best_effort(&pingSubscriber, &node,
	          ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Header), "/microROS/ping"));
	RCCHECK(rclc_subscription_init_best_effort(&pongSubscriber, &node,
	          ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Header), "/microROS/pong"));

	executor = rclc_executor_get_zero_initialized_executor();
	RCCHECK(rclc_executor_init(&executor, &support.context, 3, &allocator));
	RCCHECK(rclc_executor_add_subscription(&executor, &pingSubscriber, &incomingPing,
	                                       send_pong, ON_NEW_DATA));
	RCCHECK(rclc_executor_add_subscription(&executor, &pongSubscriber, &incomingPong,
	                                       send_ping, ON_NEW_DATA));
	microkit_dbg_puts("ping_pong: micro-ROS client initialized.\n");
}

void notified(microkit_channel ch)
{
	switch (ch) {
	case CHAN_READY: {
		transport_networking_init();
		transport_rmw_init();
		ros_setup();
		send_ping(NULL);
		break;
	}
	case CHAN_PINGPONG: {
		if (!transport_is_ready()) {
			microkit_dbg_puts("ping_pong: Early CHAN_PINGPONG, transport not ready\n");
			break;
		}
		if (spsc_empty(spsc_vmm2pd)) {
			microkit_dbg_puts("notified but queue is empty\n");
			break;
		}
		rclc_executor_spin_some(&executor, 0);
		break;
	}
	default:
		microkit_dbg_puts("ping_pong: Unknown channel\n");
	}
}

static void send_impl(std_msgs__msg__Header *hdr, rcl_publisher_t *publisher)
{
	hdr->frame_id.size = snprintf(hdr->frame_id.data, hdr->frame_id.capacity,
	                              "%d_%d", seqNum, DEVICE_ID);
	hdr->stamp.sec = 0;
	hdr->stamp.nanosec = 0;
	RCCHECK(rcl_publish(publisher, (const void *)hdr, NULL));
	seqNum++;
}
