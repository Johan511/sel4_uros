#!/usr/bin/env python3
import sys

def _count(lines, token):
    return sum(1 for line in lines if token in line)

def test_ping_pong(lines):
    NUM_PINGS = 1000
    ping_count = _count(lines, "sent_ping")
    pong_count = _count(lines, "sent_pong")
    errors = []
    if ping_count != NUM_PINGS:
        errors.append(f"Expected {NUM_PINGS} sent_ping, got {ping_count}")
    if pong_count != NUM_PINGS:
        errors.append(f"Expected {NUM_PINGS} sent_pong, got {pong_count}")
    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print(f"PASS: {ping_count} pings, {pong_count} pongs")
    return 0

def test_int32_pubsub(lines):
    NUM_MSGS = 1000
    sent = _count(lines, "SENT")
    recv = _count(lines, "RECEIVED")
    errors = []
    if sent != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} SENT, got {sent}")
    if recv != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} RECEIVED, got {recv}")
    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print(f"PASS: {sent} SENT, {recv} RECEIVED")
    return 0

def test_string_pubsub(lines):
    NUM_MSGS = 1000
    sent = _count(lines, "SENT")
    recv = _count(lines, "RECEIVED")
    errors = []
    if sent != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} SENT, got {sent}")
    if recv != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} RECEIVED, got {recv}")
    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print(f"PASS: {sent} SENT, {recv} RECEIVED")
    return 0

def test_fragmented_pubsub(lines):
    NUM_MSGS = 1000
    sent = _count(lines, "SENT")
    ok   = _count(lines, "OK")
    errors = []
    if sent != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} SENT, got {sent}")
    if ok != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} OK, got {ok}")
    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print(f"PASS: {sent} SENT, {ok} OK")
    return 0

def test_complex_msg_pubsub(lines):
    NUM_MSGS = 1000
    sent = _count(lines, "SENT")
    recv = _count(lines, "RECEIVED")
    errors = []
    if sent != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} SENT, got {sent}")
    if recv != NUM_MSGS:
        errors.append(f"Expected {NUM_MSGS} RECEIVED, got {recv}")
    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print(f"PASS: {sent} SENT, {recv} RECEIVED")
    return 0

def test_ping_uros_agent(lines):
    up = _count(lines, "AGENT_UP")
    if up != 1:
        print(f"FAIL: Expected 1 AGENT_UP, got {up}", file=sys.stderr)
        return 1
    print("PASS: agent is up")
    return 0

def test_addtwoints(lines):
    send_req = _count(lines, "SEND_REQ")
    served   = _count(lines, "SERVED")
    resp_ok  = _count(lines, "RESPONSE_OK")
    errors = []
    if send_req != 1:
        errors.append(f"Expected 1 SEND_REQ, got {send_req}")
    if served != 1:
        errors.append(f"Expected 1 SERVED, got {served}")
    if resp_ok != 1:
        errors.append(f"Expected 1 RESPONSE_OK, got {resp_ok}")
    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print("PASS: service request/response OK")
    return 0

def test_fibonacci_action(lines):
    send_goal     = _count(lines, "SEND_GOAL")
    goal_accepted = _count(lines, "GOAL_ACCEPTED")
    goal_done     = _count(lines, "GOAL_DONE")
    result_ok     = _count(lines, "RESULT_OK")
    errors = []
    if send_goal != 1:
        errors.append(f"Expected 1 SEND_GOAL, got {send_goal}")
    if goal_accepted != 1:
        errors.append(f"Expected 1 GOAL_ACCEPTED, got {goal_accepted}")
    if goal_done != 1:
        errors.append(f"Expected 1 GOAL_DONE, got {goal_done}")
    if result_ok != 1:
        errors.append(f"Expected 1 RESULT_OK, got {result_ok}")
    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print("PASS: action goal/result OK")
    return 0


TESTS = {
    "ping_pong":          test_ping_pong,
    "int32_pubsub":       test_int32_pubsub,
    "string_pubsub":      test_string_pubsub,
    "fragmented_pubsub":  test_fragmented_pubsub,
    "complex_msg_pubsub": test_complex_msg_pubsub,
    "ping_uros_agent":    test_ping_uros_agent,
    "addtwoints":         test_addtwoints,
    "fibonacci_action":   test_fibonacci_action,
}


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <example_name> [logfile]", file=sys.stderr)
        print(f"Available examples: {', '.join(sorted(TESTS))}", file=sys.stderr)
        sys.exit(2)

    example = sys.argv[1]
    test_fn = TESTS.get(example)
    if test_fn is None:
        print(f"ERROR: unknown example '{example}'", file=sys.stderr)
        print(f"Available: {', '.join(sorted(TESTS))}", file=sys.stderr)
        sys.exit(2)

    if len(sys.argv) > 2:
        with open(sys.argv[2]) as f:
            lines = f.readlines()
    else:
        lines = sys.stdin.readlines()

    sys.exit(test_fn(lines))


if __name__ == "__main__":
    main()
