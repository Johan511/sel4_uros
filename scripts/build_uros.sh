#!/bin/bash
set -e

UROS_ROS2_SETUP="${1:?}"
UROS_DEV_WS_SETUP="${2:?}"
UROS_MCU_WS_DIR="${3:?}"
UROS_TOOLCHAIN_FILE="${4:?}"
UROS_C_FLAGS="${5:?}"
UROS_CXX_FLAGS="${6:?}"
UROS_TOOLCHAIN_PREFIX="${7:?}"

source "${UROS_ROS2_SETUP}"

export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/opt/ros/' | paste -sd: -)

unset AMENT_PREFIX_PATH COLCON_PREFIX_PATH CMAKE_PREFIX_PATH
unset LD_LIBRARY_PATH PYTHONPATH

source "${UROS_DEV_WS_SETUP}"

export UROS_TOOLCHAIN_PREFIX

cd "${UROS_MCU_WS_DIR}"
rm -rf build install log

colcon build \
    --merge-install \
    --packages-ignore-regex '.*_cpp' \
    --metas colcon.meta \
    --cmake-args \
        --no-warn-unused-cli \
        "-DCMAKE_TOOLCHAIN_FILE=${UROS_TOOLCHAIN_FILE}" \
        "-DCMAKE_C_FLAGS=${UROS_C_FLAGS}" \
        "-DCMAKE_CXX_FLAGS=${UROS_CXX_FLAGS}" \
        -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=OFF \
        -DTHIRDPARTY=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_VERBOSE_MAKEFILE=ON
