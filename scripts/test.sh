#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE="${1:-ping_pong}"
LOG_FILE="$(mktemp /tmp/sel4_test_output.XXXXXX)"
TIMEOUT_SEC="${TEST_TIMEOUT:-15}"
RUN_SH="$SCRIPT_DIR/run.sh"
TEST_PY="$SCRIPT_DIR/validate_example.py"

cleanup() { rm -f "$LOG_FILE"; }
trap cleanup EXIT

echo "Running $EXAMPLE via run.sh (timeout: ${TIMEOUT_SEC}s)..."
echo "Log: $LOG_FILE"

timeout --foreground "$TIMEOUT_SEC" bash "$RUN_SH" "$EXAMPLE" > "$LOG_FILE" 2>&1 || true

echo ""
python3 "$TEST_PY" "$EXAMPLE" "$LOG_FILE"
