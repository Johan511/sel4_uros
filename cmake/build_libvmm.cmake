# build_libvmm.cmake — Build libvmm.a (VMM library for seL4)
#
# Provides:
#   libvmm  — static library target
#
# Compiled with the project compiler (aarch64-linux-gnu-gcc) using bare-metal
# VMM flags (with -include microkit.h).  Depends on sddf_util_debug for SDDF
# include paths (the library is linked separately at ELF link time).

# TODO: clean this AI slop

include_guard(GLOBAL)

set(LIBVMM_SRC "${LIBVMM_DIR}/src")

set(LIBVMM_AARCH64_SOURCES
    "${LIBVMM_SRC}/arch/aarch64/fault.c"
    "${LIBVMM_SRC}/arch/aarch64/linux.c"
    "${LIBVMM_SRC}/arch/aarch64/cpuif.c"
    "${LIBVMM_SRC}/arch/aarch64/psci.c"
    "${LIBVMM_SRC}/arch/aarch64/smc.c"
    "${LIBVMM_SRC}/arch/aarch64/tcb.c"
    "${LIBVMM_SRC}/arch/aarch64/vcpu.c"
    "${LIBVMM_SRC}/arch/aarch64/virq.c"
    "${LIBVMM_SRC}/arch/aarch64/vgic/vgic.c"
    "${LIBVMM_SRC}/arch/aarch64/vgic/vgic_v2.c"
    "${LIBVMM_SRC}/arch/aarch64/vgic/vgic_v3.c"
    "${LIBVMM_SRC}/arch/aarch64/vgic/vgic_v3_cpuif.c"
    "${LIBVMM_SRC}/arch/aarch64/guest.c"
)

set(LIBVMM_ARCH_INDEP_SOURCES
    "${LIBVMM_SRC}/virtio/block.c"
    "${LIBVMM_SRC}/virtio/console.c"
    "${LIBVMM_SRC}/virtio/mmio.c"
    "${LIBVMM_SRC}/virtio/pci.c"
    "${LIBVMM_SRC}/virtio/net.c"
    "${LIBVMM_SRC}/virtio/sound.c"
    "${LIBVMM_SRC}/virtio/virtio.c"
    "${LIBVMM_SRC}/util/util.c"
    "${LIBVMM_SRC}/guest_ram.c"
)

add_library(libvmm STATIC ${LIBVMM_AARCH64_SOURCES} ${LIBVMM_ARCH_INDEP_SOURCES})
add_dependencies(libvmm musllibc_lib)

get_target_property(_musl_inc musllibc_lib INTERFACE_INCLUDE_DIRECTORIES)

target_include_directories(libvmm
    PRIVATE ${_musl_inc} "${BOARD_DIR}/include"
    PUBLIC  "${LIBVMM_DIR}/include" "${SDDF_DIR}/include" "${SDDF_DIR}/include/microkit"
)

target_compile_options(libvmm PRIVATE
    -include "${BOARD_DIR}/include/microkit.h"
    ${SEL4_C_FLAGS}
    -DBOARD_${MICROKIT_BOARD}
)

target_compile_definitions(libvmm PRIVATE BOARD_${MICROKIT_BOARD})
