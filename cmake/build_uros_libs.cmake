# build_uros_libs.cmake — Cross-compile micro-ROS static library for seL4
#
# Provides:
#   microros        — custom target that builds and packs libmicroros.a
#   microros_lib    — imported STATIC library (IMPORTED_LOCATION + INTERFACE_INCLUDE_DIRECTORIES)
#

# TODO: find a better way

include_guard(GLOBAL)

set(UROS_FIRMWARE_DIR "${CMAKE_SOURCE_DIR}/third_party/firmware" CACHE PATH
    "micro-ROS firmware workspace root (created by scripts/setup.sh)")
set(UROS_ROS2_SETUP "/opt/ros/humble/setup.bash" CACHE FILEPATH
    "ROS 2 Humble setup script")
set(UROS_TOOLCHAIN_PREFIX "${CMAKE_SOURCE_DIR}/third_party/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf" CACHE PATH
    "bare-metal aarch64-none-elf toolchain prefix")

set(UROS_BUILD_DIR       "${CMAKE_BINARY_DIR}/uros")
set(UROS_MCU_WS_DIR      "${UROS_FIRMWARE_DIR}/mcu_ws")
set(UROS_DEV_WS_SETUP    "${UROS_FIRMWARE_DIR}/dev_ws/install/setup.bash")
set(UROS_COLCON_META     "${UROS_MCU_WS_DIR}/colcon.meta")
set(UROS_OUTPUT_LIB      "${UROS_BUILD_DIR}/lib/libmicroros.a")
set(UROS_OUTPUT_INCLUDE  "${UROS_BUILD_DIR}/include")
set(UROS_TOOLCHAIN_FILE  "${CMAKE_SOURCE_DIR}/cmake/toolchain-aarch64-none-elf.cmake")

set(UROS_CC     "${UROS_TOOLCHAIN_PREFIX}/bin/aarch64-none-elf-gcc")
set(UROS_CXX    "${UROS_TOOLCHAIN_PREFIX}/bin/aarch64-none-elf-g++")
set(UROS_AR     "${UROS_TOOLCHAIN_PREFIX}/bin/aarch64-none-elf-ar")
set(UROS_RANLIB "${UROS_TOOLCHAIN_PREFIX}/bin/aarch64-none-elf-ranlib")

if(NOT EXISTS "${UROS_CC}")
    message(FATAL_ERROR
        "Cross-compiler not found at ${UROS_CC}\n"
        "Set UROS_TOOLCHAIN_PREFIX to the toolchain install directory")
endif()

if(NOT EXISTS "${UROS_DEV_WS_SETUP}")
    message(FATAL_ERROR
        "micro-ROS firmware workspace not found at:\n"
        "  ${UROS_FIRMWARE_DIR}\n"
        "Run './scripts/setup.sh' to create it, or set UROS_FIRMWARE_DIR")
endif()

if(NOT EXISTS "${UROS_ROS2_SETUP}")
    message(FATAL_ERROR
        "ROS 2 Humble not found at ${UROS_ROS2_SETUP}\n"
        "Install ROS 2 Humble and set UROS_ROS2_SETUP if needed")
endif()

get_target_property(_musl_dirs musllibc_lib INTERFACE_INCLUDE_DIRECTORIES)
set(UROS_MUSL_INCLUDES "")
foreach(_inc IN LISTS _musl_dirs)
    string(APPEND UROS_MUSL_INCLUDES " -I${_inc}")
endforeach()

file(MAKE_DIRECTORY "${UROS_BUILD_DIR}")

set(UROS_C_FLAGS "-nostdlib -ffreestanding ${UROS_MUSL_INCLUDES} \${CMAKE_C_FLAGS}")
set(UROS_CXX_FLAGS "-nostdlib -ffreestanding ${UROS_MUSL_INCLUDES} \${CMAKE_CXX_FLAGS}")

set(UROS_META_STAMP "${UROS_BUILD_DIR}/colcon_meta.stamp")
add_custom_command(
    OUTPUT "${UROS_META_STAMP}"
    COMMAND ${CMAKE_COMMAND} -E env "FW_DIR=${UROS_FIRMWARE_DIR}"
        python3 "${CMAKE_SOURCE_DIR}/scripts/update_colcon.py"
    COMMAND ${CMAKE_COMMAND} -E touch "${UROS_META_STAMP}"
    DEPENDS
        "${CMAKE_SOURCE_DIR}/scripts/update_colcon.py"
        "${UROS_COLCON_META}"
    COMMENT "Patching colcon.meta for micro-ROS custom transport"
)

add_custom_command(
    OUTPUT "${UROS_OUTPUT_LIB}"
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/build_uros.sh"
        "${UROS_ROS2_SETUP}"
        "${UROS_DEV_WS_SETUP}"
        "${UROS_MCU_WS_DIR}"
        "${UROS_TOOLCHAIN_FILE}"
        "${UROS_C_FLAGS}"
        "${UROS_CXX_FLAGS}"
        "${UROS_TOOLCHAIN_PREFIX}"
    COMMAND python3 "${CMAKE_SOURCE_DIR}/scripts/pack_microros.py"
        "${UROS_MCU_WS_DIR}/install/lib"
        "${UROS_OUTPUT_LIB}"
        "${UROS_MCU_WS_DIR}/install/include"
        "${UROS_OUTPUT_INCLUDE}"
        "${UROS_AR}"
        "${UROS_RANLIB}"
    DEPENDS
        "${UROS_META_STAMP}"
        musllibc_lib
        "${UROS_COLCON_META}"
        "${CMAKE_SOURCE_DIR}/scripts/build_uros.sh"
        "${CMAKE_SOURCE_DIR}/scripts/pack_microros.py"
    COMMENT "Cross-compiling and packing micro-ROS libraries"
)

add_custom_target(microros ALL DEPENDS "${UROS_OUTPUT_LIB}")

add_library(microros_lib STATIC IMPORTED GLOBAL)
set_property(TARGET microros_lib PROPERTY IMPORTED_LOCATION "${UROS_OUTPUT_LIB}")
file(MAKE_DIRECTORY "${UROS_OUTPUT_INCLUDE}")

set_property(TARGET microros_lib PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${UROS_OUTPUT_INCLUDE}")
add_dependencies(microros_lib microros)
