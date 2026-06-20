# build_sddf.cmake — Build libsddf_util_debug.a (SDDF utility library)
#
# Provides:
#   sddf_util_debug  — static library target
#
# Compiled with the project compiler (aarch64-linux-gnu-gcc) using bare-metal
# flags matching the VMM protection domain (with -include microkit.h).

# TODO: clean this AI slop

include_guard(GLOBAL)

set(MICROKIT_SDK "${CMAKE_SOURCE_DIR}/third_party/microkit-sdk-1.4.1" CACHE PATH "microkit SDK install directory")
set(MICROKIT_BOARD "qemu_virt_aarch64" CACHE STRING "microkit board name")
set(MICROKIT_CONFIG "debug" CACHE STRING "microkit configuration (debug/release/benchmark)")
set(LIBVMM_DIR "${CMAKE_SOURCE_DIR}/third_party/libvmm" CACHE PATH "libvmm source directory")
set(SDDF_DIR "${LIBVMM_DIR}/dep/sddf")

set(BOARD_DIR "${MICROKIT_SDK}/board/${MICROKIT_BOARD}/${MICROKIT_CONFIG}")

if(NOT EXISTS "${BOARD_DIR}/include/microkit.h")
    message(FATAL_ERROR "microkit SDK board not found at ${BOARD_DIR}")
endif()

get_target_property(_musl_inc musllibc_lib INTERFACE_INCLUDE_DIRECTORIES)

set(SDDF_SOURCES
    "${SDDF_DIR}/util/cache.c"
    "${SDDF_DIR}/util/printf.c"
    "${SDDF_DIR}/util/assert.c"
    "${SDDF_DIR}/util/bitarray.c"
    "${SDDF_DIR}/util/fsmalloc.c"
    "${SDDF_DIR}/util/putchar_debug.c"
)

add_library(sddf_util_debug STATIC ${SDDF_SOURCES})
add_dependencies(sddf_util_debug musllibc_lib)

target_include_directories(sddf_util_debug
    PRIVATE ${_musl_inc} "${BOARD_DIR}/include"
    PUBLIC  "${SDDF_DIR}/include" "${SDDF_DIR}/include/microkit"
)

target_compile_options(sddf_util_debug PRIVATE
    -include "${BOARD_DIR}/include/microkit.h"
    ${SEL4_C_FLAGS}
    -DBOARD_${MICROKIT_BOARD}
)

target_compile_definitions(sddf_util_debug PRIVATE BOARD_${MICROKIT_BOARD})
