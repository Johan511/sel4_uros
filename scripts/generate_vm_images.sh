#!/bin/bash
#
# generate_vm_images.sh - Build minimal Linux kernel + rootfs for the seL4 VM guest
#
# Builds everything from source:
#   1. Linux kernel 5.18 with a minimal config targeting only the VM's needs
#   2. Static busybox with only the applets needed by init + agent scripts
#   3. Minimal rootfs with config files, device nodes, and init scripts
#   4. Device tree blob matching this project's VMM (src/vmm/vmm.c)
#
# Uses the system aarch64-linux-gnu-gcc toolchain.
#
# Output:
#   third_party/vm_images/linux           - minimal aarch64 Linux Image
#   third_party/vm_images/linux.dts       - device tree source
#   third_party/vm_images/rootfs.cpio.gz  - rootfs initramfs
#
# Usage: ./scripts/generate_vm_images.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LINUX_VERSION="5.18"
BUSYBOX_VERSION="1.35.0"

LINUX_URL="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VERSION}.tar.xz"
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"

CROSS_COMPILE="aarch64-linux-gnu-"
BUILD_DIR="/tmp/kilo/vm-images-build"
LINUX_SRC_DIR="$BUILD_DIR/linux-${LINUX_VERSION}"
BUSYBOX_SRC_DIR="$BUILD_DIR/busybox-${BUSYBOX_VERSION}"

VM_IMAGES_DIR="$PROJECT_DIR/vm_images"
KERNEL_OUT="$VM_IMAGES_DIR/linux"
DTS_OUT="$VM_IMAGES_DIR/linux.dts"
ROOTFS_OUT="$VM_IMAGES_DIR/rootfs.cpio.gz"

KERNEL_CONFIG="$SCRIPT_DIR/vm_files/kernel.config"
BUSYBOX_CONFIG="$SCRIPT_DIR/vm_files/busybox.config"
DTS_SRC="$SCRIPT_DIR/vm_files/linux.dts"
ROOTFS_SRC="$SCRIPT_DIR/vm_files/rootfs"

NPROC="${NPROC:-$(nproc)}"

# helpers
step() { echo ""; echo "=== $1 ==="; }
die()  { echo "ERROR: $*" >&2; exit 1; }
require() { command -v "$1" &>/dev/null || die "required command not found: $1"; }

# ------------------------------------------------------------------
# Prerequisites
# ------------------------------------------------------------------
check_prereqs() {
    step "Checking prerequisites"
    require curl; require tar; require make; require gzip; require cpio; require dtc; require xz; require bc
    require aarch64-linux-gnu-gcc
    require aarch64-linux-gnu-strip
    echo "Toolchain: $(aarch64-linux-gnu-gcc --version | head -1)"
}

# ------------------------------------------------------------------
# Phase 1: Download and extract Linux source
# ------------------------------------------------------------------
download_linux() {
    step "Phase 1: Linux kernel source"
    if [ -f "$LINUX_SRC_DIR/Makefile" ]; then
        echo "Already extracted at $LINUX_SRC_DIR"
        return
    fi
    mkdir -p "$BUILD_DIR"
    echo "Downloading $LINUX_URL ..."
    curl -L --progress-bar -o "$BUILD_DIR/linux.tar.xz" "$LINUX_URL"
    echo "Extracting..."
    tar -xf "$BUILD_DIR/linux.tar.xz" -C "$BUILD_DIR"
    rm -f "$BUILD_DIR/linux.tar.xz"
}

# ------------------------------------------------------------------
# Phase 2: Minimal kernel config and build
# ------------------------------------------------------------------
build_kernel() {
    step "Phase 2: Building Linux kernel"

    local kernel_img="$LINUX_SRC_DIR/arch/arm64/boot/Image"
    if [ -f "$kernel_img" ]; then
        echo "Kernel Image already built, skipping build."
        mkdir -p "$VM_IMAGES_DIR"
        cp "$kernel_img" "$KERNEL_OUT"
        echo "Kernel:  $(ls -lh "$KERNEL_OUT" | awk '{print $5}')"
        return
    fi

    pushd "$LINUX_SRC_DIR" > /dev/null

    echo "Generating allnoconfig base..."
    make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" allnoconfig

    echo "Merging kernel config fragment..."
    if [ -x scripts/kconfig/merge_config.sh ]; then
        ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" \
            scripts/kconfig/merge_config.sh -m .config "$KERNEL_CONFIG"
        make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
    else
        echo "Merging config fragment manually..."
        while IFS='=' read -r key val; do
            key="${key%% }"; val="${val%% }"
            [ -z "$key" ] && continue
            [ "${key:0:1}" = "#" ] && continue
            if grep -q "^# ${key} is not set" .config; then
                sed -i "s|^# ${key} is not set|${key}=${val}|" .config
            elif grep -q "^${key}=" .config; then
                sed -i "s|^${key}=.*|${key}=${val}|" .config
            else
                echo "${key}=${val}" >> .config
            fi
        done < "$KERNEL_CONFIG"
        make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
    fi

    echo "Building Linux ${LINUX_VERSION} (${NPROC} jobs)..."
    make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" Image -j"$NPROC"

    popd > /dev/null

    [ -f "$kernel_img" ] || die "Kernel build failed - Image not found"

    echo "Kernel Image ready."

    mkdir -p "$VM_IMAGES_DIR"
    cp "$kernel_img" "$KERNEL_OUT"
    echo "Kernel:  $(ls -lh "$KERNEL_OUT" | awk '{print $5}')"
}

# ------------------------------------------------------------------
# Phase 3: Download and build static busybox
# ------------------------------------------------------------------
build_busybox() {
    step "Phase 3: Building static busybox"

    if [ ! -f "$BUSYBOX_SRC_DIR/Makefile" ]; then
        mkdir -p "$BUILD_DIR"
        echo "Downloading $BUSYBOX_URL ..."
        curl -L --progress-bar -o "$BUILD_DIR/busybox.tar.bz2" "$BUSYBOX_URL"
        echo "Extracting..."
        tar -xf "$BUILD_DIR/busybox.tar.bz2" -C "$BUILD_DIR"
        rm -f "$BUILD_DIR/busybox.tar.bz2"
    fi

    pushd "$BUSYBOX_SRC_DIR" > /dev/null

    make allnoconfig CC="${CROSS_COMPILE}gcc"

    echo "Merging busybox config..."
    while IFS='=' read -r key val; do
        key="${key%% }"; val="${val%% }"
        [ -z "$key" ] && continue
        [ "${key:0:1}" = "#" ] && continue
        if grep -q "^# ${key} is not set" .config; then
            sed -i "s|^# ${key} is not set|${key}=${val}|" .config
        elif grep -q "^${key}=" .config; then
            sed -i "s|^${key}=.*|${key}=${val}|" .config
        else
            echo "${key}=${val}" >> .config
        fi
    done < "$BUSYBOX_CONFIG"
    make oldconfig CC="${CROSS_COMPILE}gcc"

    echo "Building busybox ${BUSYBOX_VERSION}..."
    make CC="${CROSS_COMPILE}gcc" STRIP="${CROSS_COMPILE}strip" -j"$NPROC"

    popd > /dev/null

    local bb="$BUSYBOX_SRC_DIR/busybox"
    [ -f "$bb" ] || die "Busybox build failed"
    echo "Busybox:  $(ls -lh "$bb" | awk '{print $5}')"
}

# ------------------------------------------------------------------
# Phase 4: Create minimal rootfs
# ------------------------------------------------------------------
create_rootfs() {
    step "Phase 4: Creating minimal rootfs"

    local bb="$BUSYBOX_SRC_DIR/busybox"
    [ -f "$bb" ] || die "Busybox binary not found at $bb"

    local tmpdir
    tmpdir="$(mktemp -d)"
    pushd "$tmpdir" > /dev/null

    mkdir -p bin dev lib proc sys tmp run root sbin

    cp "$bb" bin/busybox
    chmod 755 bin/busybox

    for a in init getty mount mkdir mknod chmod ln rm cp mv ls \
             echo cat sleep true false test [ expr grep sed hostname \
             ip arp ifconfig route udhcpc kill ps pidof \
             head tail cut sort wc tr basename dirname readlink realpath \
             find xargs date uname touch tar gzip gunzip more sh ash; do
        ln -sf busybox "bin/$a" 2>/dev/null || true
    done
    ln -sf bin/busybox init
    ln -sf ../bin/busybox sbin/init

    cp -a "$ROOTFS_SRC/." .

    chmod 755 etc/init.d/rcS etc/init.d/rcK etc/network/if-pre-up.d/wait_iface

    mknod dev/console c 5 1
    mknod dev/null    c 1 3

    echo "Repacking rootfs..."
    find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 > "$ROOTFS_OUT"

    popd > /dev/null
    rm -rf "$tmpdir"

    echo "Rootfs:  $(ls -lh "$ROOTFS_OUT" | awk '{print $5}')"
}

# ------------------------------------------------------------------
# Phase 5: Create device tree source
# ------------------------------------------------------------------
create_dts() {
    step "Phase 5: Creating device tree source"

    mkdir -p "$VM_IMAGES_DIR"
    cp "$DTS_SRC" "$DTS_OUT"
    echo "DTS:     $(wc -l < "$DTS_OUT") lines"
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
main() {
    echo "=== generate_vm_images.sh ==="
    echo "Project:    $PROJECT_DIR"
    echo "Linux:      $LINUX_VERSION"
    echo "Busybox:    $BUSYBOX_VERSION"
    echo "Jobs:       $NPROC"

    check_prereqs
    download_linux
    build_kernel
    build_busybox
    create_rootfs
    create_dts

    step "Complete"
    echo "Output files:"
    ls -lh "$KERNEL_OUT" "$DTS_OUT" "$ROOTFS_OUT"
}

main "$@"
