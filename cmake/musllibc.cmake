# musllibc.cmake — Download, configure, and build musllibc for aarch64-linux-gnu
#
# Provides:
#   musllibc       — custom target that builds libc.a
#   musllibc_lib   — imported STATIC library (IMPORTED_LOCATION + INTERFACE_INCLUDE_DIRECTORIES)
#
# The source is expected at MUSLLIBC_SOURCE_DIR (default: third_party/musllibc/).
# Run scripts/setup.sh first to clone it.

include_guard(GLOBAL)

set(MUSLLIBC_SOURCE_DIR "${CMAKE_SOURCE_DIR}/third_party/musllibc" CACHE PATH
    "musllibc source directory (clone via ./scripts/setup.sh)")
set(MUSLLIBC_BUILD_DIR  "${CMAKE_BINARY_DIR}/musllibc_build")
file(MAKE_DIRECTORY "${MUSLLIBC_BUILD_DIR}")
file(MAKE_DIRECTORY "${MUSLLIBC_BUILD_DIR}/obj/include")

if(NOT EXISTS "${MUSLLIBC_SOURCE_DIR}/configure")
    message(FATAL_ERROR
        "musllibc source not found at:\n"
        "  ${MUSLLIBC_SOURCE_DIR}\n"
        "Run './scripts/setup.sh' to clone it, or set MUSLLIBC_SOURCE_DIR:\n"
        "  cmake -DMUSLLIBC_SOURCE_DIR=/path/to/musllibc ...")
endif()

set(MUSLLIBC_CROSS_COMPILE "aarch64-linux-gnu-" CACHE STRING "musllibc cross-compile prefix")
set(MUSLLIBC_CC "${MUSLLIBC_CROSS_COMPILE}gcc" CACHE STRING "musllibc C compiler")
set(MUSLLIBC_AR "${MUSLLIBC_CROSS_COMPILE}ar" CACHE STRING "musllibc archiver")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(MUSLLIBC_CFLAGS "${MUSLLIBC_CFLAGS} -g -O0")
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(MUSLLIBC_CFLAGS "${MUSLLIBC_CFLAGS} -O3 -DNDEBUG")
elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
    set(MUSLLIBC_CFLAGS "${MUSLLIBC_CFLAGS} -Os -DNDEBUG")
else()
    set(MUSLLIBC_CFLAGS "${MUSLLIBC_CFLAGS} -O2 -g")
endif()
string(STRIP "${MUSLLIBC_CFLAGS}" MUSLLIBC_CFLAGS)

# Use musl's seL4 wrapper Makefile which automatically:
#   1. runs configure with --target=aarch64
#   2. patches ARCH=aarch64 → ARCH=aarch64_sel4 (adds _sel4 suffix)
#   3. builds with Makefile.muslc
# This ensures musl uses arch/aarch64_sel4/syscall_arch.h (CALL_SYSINFO
# via __sysinfo) instead of arch/aarch64/syscall_arch.h (svc #0).
set(MUSLLIBC_LIBRARY "${MUSLLIBC_BUILD_DIR}/lib/libc.a")
# Wipe config.mak so the wrapper always re-configures from scratch.
# The wrapper's sed 's/ARCH = \(.*\)/ARCH = \1_sel4/' is not
# idempotent — if ARCH already ends with _sel4 it would produce
# aarch64_sel4_sel4. Starting fresh ensures ARCH=aarch64 → _sel4 once.
add_custom_command(
    OUTPUT "${MUSLLIBC_LIBRARY}"
    COMMAND ${CMAKE_COMMAND} -E rm -f "${MUSLLIBC_BUILD_DIR}/config.mak"
    COMMAND ${CMAKE_COMMAND} -E rm -f "${MUSLLIBC_BUILD_DIR}/configure_line"
    COMMAND ${CMAKE_MAKE_PROGRAM} -j${CMAKE_NUMBER_OF_PROCESSORS}
        "CONFIG_ARCH_AARCH64=y"
        "SOURCE_DIR=${MUSLLIBC_SOURCE_DIR}"
        "STAGE_DIR=${MUSLLIBC_BUILD_DIR}/install"
        "C_COMPILER=${MUSLLIBC_CC}"
        "TOOLPREFIX=${MUSLLIBC_CROSS_COMPILE}"
        "CFLAGS=${MUSLLIBC_CFLAGS}"
        -f "${MUSLLIBC_SOURCE_DIR}/Makefile"
    WORKING_DIRECTORY "${MUSLLIBC_BUILD_DIR}"
    COMMENT "Building musllibc → libc.a (via seL4 wrapper)"
)
add_custom_target(musllibc DEPENDS "${MUSLLIBC_LIBRARY}")

add_library(musllibc_lib STATIC IMPORTED GLOBAL)
set_property(TARGET musllibc_lib PROPERTY IMPORTED_LOCATION "${MUSLLIBC_LIBRARY}")
set_property(TARGET musllibc_lib PROPERTY INTERFACE_INCLUDE_DIRECTORIES
    "${MUSLLIBC_BUILD_DIR}/obj/include"
    "${MUSLLIBC_SOURCE_DIR}/include"
    "${MUSLLIBC_SOURCE_DIR}/arch/aarch64_sel4"
    "${MUSLLIBC_SOURCE_DIR}/arch/generic"
)
add_dependencies(musllibc_lib musllibc)
