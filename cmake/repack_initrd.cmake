# repack_initrd.cmake — Repack the VM guest initrd with agent + helper binaries
#
# Produces: vm_images/rootfs.cpio.gz

include_guard(GLOBAL)

set(VM_IMAGES_DIR "${CMAKE_SOURCE_DIR}/vm_images" CACHE PATH "VM guest images directory")
set(INITRD_ORIG "${VM_IMAGES_DIR}/rootfs.cpio.gz.orig")
set(INITRD_OUT  "${VM_IMAGES_DIR}/rootfs.cpio.gz")
set(ROS_AGENT_INIT "${CMAKE_SOURCE_DIR}/src/examples/S100_ros_agent")
set(ROS_MOUNTS_INIT "${CMAKE_SOURCE_DIR}/src/examples/S00_mounts")
set(REPACK_SCRIPT "${CMAKE_SOURCE_DIR}/scripts/repack_initrd.sh")

if(NOT EXISTS "${INITRD_ORIG}")
    message(FATAL_ERROR "Original initrd not found at ${INITRD_ORIG}. Run ./scripts/setup.sh first.")
endif()

set(AGENT_BIN "${CMAKE_SOURCE_DIR}/third_party/Micro-XRCE-DDS-Agent/build_ws/MicroXRCEAgent")

if(NOT EXISTS "${AGENT_BIN}")
    message(FATAL_ERROR "MicroXRCEAgent not found at ${AGENT_BIN}. Run ./scripts/setup.sh first.")
endif()

add_custom_target(repack_initrd ALL
    COMMAND bash "${REPACK_SCRIPT}"
        "${INITRD_ORIG}"
        "${INITRD_OUT}"
        "${AGENT_BIN}"
        "$<TARGET_FILE:is_port_open>"
        "${ROS_AGENT_INIT}"
        "${ROS_MOUNTS_INIT}"
    DEPENDS is_port_open_target "${ROS_AGENT_INIT}" "${ROS_MOUNTS_INIT}" "${INITRD_ORIG}" "${REPACK_SCRIPT}"
    COMMENT "Repacking initrd → ${INITRD_OUT}"
)
