#!/bin/bash
set -e
ORIG="$1"
OUT="$2"
AGENT_BIN="$3"
IS_PORT_OPEN="$4"
ROS_AGENT_INIT="$5"
MOUNTS_INIT="$6"

TMP=$(mktemp -d)
pushd "$TMP" > /dev/null

zcat "$ORIG" | cpio -idm 2>/dev/null
chmod +x etc/init.d/rcS etc/init.d/rcK
cp "$AGENT_BIN" bin/MicroXRCEAgent
chmod +x bin/MicroXRCEAgent
cp "$ROS_AGENT_INIT" etc/init.d/S100_ros_agent
chmod +x etc/init.d/S100_ros_agent
cp "$IS_PORT_OPEN" bin/is_port_open
chmod +x bin/is_port_open
if [ -n "$MOUNTS_INIT" ] && [ -f "$MOUNTS_INIT" ]; then
    cp "$MOUNTS_INIT" etc/init.d/S00_mounts
    chmod +x etc/init.d/S00_mounts
fi
test -e dev/mem || mknod dev/mem c 1 1
find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 > "$OUT"

popd > /dev/null
rm -rf "$TMP"
