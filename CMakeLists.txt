cmake_minimum_required(VERSION 3.22)

if(NOT CMAKE_TOOLCHAIN_FILE AND NOT DEFINED CMAKE_C_COMPILER)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/toolchain-aarch64-none-elf.cmake")
endif()

project(uros_sel4 LANGUAGES C CXX ASM)

set(MICROKIT_SDK "${CMAKE_SOURCE_DIR}/third_party/microkit-sdk-2.2.0" CACHE PATH "microkit SDK")
set(MICROKIT_BOARD "qemu_virt_aarch64" CACHE STRING "microkit board")
set(MICROKIT_CONFIG "debug" CACHE STRING "microkit config")
set(BOARD_DIR "${MICROKIT_SDK}/board/${MICROKIT_BOARD}/${MICROKIT_CONFIG}")
set(MICROKIT_LD "${BOARD_DIR}/lib/microkit.ld")

set(SEL4_C_FLAGS -nostdlib -ffreestanding)
set(SEL4_LINK_FLAGS -nostartfiles -no-pie -Wl,--allow-multiple-definition -T${MICROKIT_LD})

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING
        "Build type: Debug, Release, RelWithDebInfo, MinSizeRel" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
        "Debug" "Release" "RelWithDebInfo" "MinSizeRel")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

include(musllibc)
include(build_sddf)
include(build_libvmm)
include(build_uros_libs)
add_subdirectory(src/utils)

include(repack_initrd)
add_subdirectory(src/stubs)
add_subdirectory(src/vmm)
add_subdirectory(src/examples/ping_pong)
