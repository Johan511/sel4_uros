# Usage: ./setup.sh
#
# All third-party downloads go into third_party/ at the project root.
#
# Environment variables:
#   MICROKIT_VERSION  - microkit SDK version (default: 1.4.1)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THIRD_PARTY_DIR="$PROJECT_DIR/third_party"
mkdir -p "$THIRD_PARTY_DIR"
MICROKIT_VERSION="${MICROKIT_VERSION:-1.4.1}"

echo "=== Installing system packages ==="
apt-get update
apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    cpio \
    gdb-multiarch \
    qemu-system-arm \
    device-tree-compiler \
    git \
    cmake \
    ninja-build \
    python3 \
    python3-pip \
    curl \
    tar \
    xz-utils

AARCH64_NONE_ELF_DIR="$THIRD_PARTY_DIR/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf"
if [ ! -d "$AARCH64_NONE_ELF_DIR" ]; then
    echo "=== Downloading aarch64-none-elf toolchain 12.2.rel1 at $AARCH64_NONE_ELF_DIR ==="
    cd "$THIRD_PARTY_DIR"
    curl -L --progress-bar -o "arm-gnu-toolchain.tar.xz" \
        "https://developer.arm.com/-/media/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf.tar.xz"
    tar -xf "arm-gnu-toolchain.tar.xz"
    rm "arm-gnu-toolchain.tar.xz"
else
    echo "aarch64-none-elf toolchain already installed at $AARCH64_NONE_ELF_DIR"
fi

MICROKIT_SDK="$THIRD_PARTY_DIR/microkit-sdk-$MICROKIT_VERSION"
if [ ! -d "$MICROKIT_SDK" ]; then
    echo "=== Downloading microkit SDK v$MICROKIT_VERSION at $MICROKIT_SDK ==="
    cd "$THIRD_PARTY_DIR"
    curl -L -o "microkit-sdk-${MICROKIT_VERSION}-linux-x86-64.tar.gz" \
        "https://github.com/seL4/microkit/releases/download/${MICROKIT_VERSION}/microkit-sdk-${MICROKIT_VERSION}-linux-x86-64.tar.gz"
    tar -xzf "microkit-sdk-${MICROKIT_VERSION}-linux-x86-64.tar.gz"
    rm "microkit-sdk-${MICROKIT_VERSION}-linux-x86-64.tar.gz"
else
    echo "Microkit SDK already installed at $MICROKIT_SDK"
fi

VM_IMAGES_DIR="$PROJECT_DIR/vm_images"
mkdir -p $VM_IMAGES_DIR
if [ ! -f "$VM_IMAGES_DIR/linux" ] || [ ! -f "$VM_IMAGES_DIR/linux.dts" ] || [ ! -f "$VM_IMAGES_DIR/rootfs.cpio.gz" ]; then
    echo "=== Generating VM images at $VM_IMAGES_DIR ==="
    bash "$SCRIPT_DIR/generate_vm_images.sh"
else
    echo "VM images already present at $VM_IMAGES_DIR"
fi

if [ -f "$VM_IMAGES_DIR/rootfs.cpio.gz" ] && [ ! -f "$VM_IMAGES_DIR/rootfs.cpio.gz.orig" ]; then
    cp "$VM_IMAGES_DIR/rootfs.cpio.gz" "$VM_IMAGES_DIR/rootfs.cpio.gz.orig"
    echo "Preserved original initrd as rootfs.cpio.gz.orig"
fi

cd "$SCRIPT_DIR"

LIBVMM_DIR="$THIRD_PARTY_DIR/libvmm"
if [ ! -d "$LIBVMM_DIR" ]; then
    echo "=== Cloning libvmm (with SDDF submodule) at $LIBVMM_DIR ==="
    git clone --depth 1 --recurse-submodules https://github.com/au-ts/libvmm "$LIBVMM_DIR"
else
    echo "libvmm already cloned at $LIBVMM_DIR"
fi

MUSLLIBC_DIR="$THIRD_PARTY_DIR/musllibc"
if [ ! -d "$MUSLLIBC_DIR" ]; then
    echo "=== Cloning musllibc at $MUSLLIBC_DIR ==="
    git clone --depth 1 https://github.com/seL4/musllibc.git "$MUSLLIBC_DIR"
else
    echo "musllibc already cloned at $MUSLLIBC_DIR"
fi

AGENT_DIR="$THIRD_PARTY_DIR/Micro-XRCE-DDS-Agent"
if [ ! -d "$AGENT_DIR" ]; then
    echo "=== Cloning Micro-XRCE-DDS-Agent v2.4.3 at $AGENT_DIR ==="
    git clone --depth 1 --branch v2.4.3 \
        https://github.com/eProsima/Micro-XRCE-DDS-Agent.git \
        "$AGENT_DIR"
else
    echo "Micro-XRCE-DDS-Agent already cloned at $AGENT_DIR"
fi

AGENT_BUILD_DIR="$AGENT_DIR/build_ws"
if [ ! -f "$AGENT_BUILD_DIR/MicroXRCEAgent" ]; then
    echo "=== Building Micro-XRCE-DDS-Agent at $AGENT_BUILD_DIR ==="
    mkdir -p "$AGENT_BUILD_DIR"
    cd "$AGENT_BUILD_DIR"
    env -u CMAKE_PREFIX_PATH -u AMENT_PREFIX_PATH -u COLCON_PREFIX_PATH \
        cmake \
            "$AGENT_DIR" \
            -DCMAKE_TOOLCHAIN_FILE="$PROJECT_DIR/cmake/toolchain-aarch64-linux-gnu.cmake" \
            -DUAGENT_SUPERBUILD=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_EXE_LINKER_FLAGS=-static \
            -DUAGENT_BUILD_EXECUTABLE=ON
    make -j12
    echo "Micro-XRCE-DDS-Agent built at $AGENT_BUILD_DIR/MicroXRCEAgent"
else
    echo "Micro-XRCE-DDS-Agent already built at $AGENT_BUILD_DIR/MicroXRCEAgent"
fi

export MICROKIT_SDK

echo ""
echo "Environment configured:"
echo "  MICROKIT_SDK=$MICROKIT_SDK"

FW_DIR="$THIRD_PARTY_DIR/firmware"
if [ -d "$FW_DIR" ]; then
    echo "micro-ROS firmware workspace already exists at $FW_DIR"
else
    echo "=== Setting up micro-ROS ==="
    if [ ! -f /opt/ros/humble/setup.bash ]; then
        echo "ERROR: ROS 2 Humble not found at /opt/ros/humble"
        echo "Install ROS 2 Humble first, then re-run ./setup.sh"
        exit 1
    fi
    source /opt/ros/humble/setup.bash

    if ros2 pkg prefix micro_ros_setup > /dev/null 2>&1; then
        echo "micro_ros_setup already available"
    elif [ -f /microros_ws/install/setup.bash ]; then
        source /microros_ws/install/setup.bash
        echo "micro_ros_setup sourced from /microros_ws"
    else
        echo "=== Building micro_ros_setup ==="
        MICROROS_WS="$THIRD_PARTY_DIR/microros_ws"
        mkdir -p "$MICROROS_WS/src"
        if [ ! -d "$MICROROS_WS/src/micro_ros_setup" ]; then
            git clone --depth 1 --branch "$ROS_DISTRO" \
                https://github.com/micro-ROS/micro_ros_setup.git \
                "$MICROROS_WS/src/micro_ros_setup"
        else
            echo "micro_ros_setup already available at $MICROROS_WS/src/micro_ros_setup"
        fi
        rosdep update
        rosdep install --from-paths "$MICROROS_WS/src" --ignore-src -y
        pushd "$MICROROS_WS" > /dev/null
        colcon build
        source install/local_setup.bash
        popd > /dev/null
        echo "micro_ros_setup built at $MICROROS_WS"
    fi

    echo "=== Creating micro-ROS firmware workspace ==="
    pushd "$THIRD_PARTY_DIR" > /dev/null
    ros2 run micro_ros_setup create_firmware_ws.sh generate_lib

    export FW_DIR
    python3 "$SCRIPT_DIR/update_colcon.py"
    popd > /dev/null
    echo "micro-ROS firmware workspace created at $FW_DIR"
fi

echo ""
echo "=== Setup complete ==="
echo "Next: Build using cmake"
echo ""
