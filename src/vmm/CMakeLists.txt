# VMM protection domain for seL4

set(DTB_SOURCE "${VM_IMAGES_DIR}/linux.dts")
set(DTB_IMAGE  "${CMAKE_CURRENT_BINARY_DIR}/linux.dtb")
add_custom_command(
    OUTPUT "${DTB_IMAGE}"
    COMMAND dtc -I dts -O dtb -o "${DTB_IMAGE}" "${DTB_SOURCE}"
    DEPENDS "${DTB_SOURCE}"
    COMMENT "Compiling device tree → ${DTB_IMAGE}"
)
add_custom_target(dtb ALL DEPENDS "${DTB_IMAGE}")

set(KERNEL_IMAGE "${VM_IMAGES_DIR}/linux")
set(INITRD_IMAGE "${VM_IMAGES_DIR}/rootfs.cpio.gz")

set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/global_data.S"
    APPEND PROPERTY COMPILE_DEFINITIONS
        "VM_KERNEL_IMAGE_PATH=\"${KERNEL_IMAGE}\""
        "VM_DTB_IMAGE_PATH=\"${DTB_IMAGE}\""
        "VM_INITRD_IMAGE_PATH=\"${INITRD_IMAGE}\""
)
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/global_data.S"
    PROPERTY OBJECT_DEPENDS "${KERNEL_IMAGE};${DTB_IMAGE};${INITRD_IMAGE}"
)

add_library(vmm_asm_obj OBJECT global_data.S)
add_dependencies(vmm_asm_obj dtb repack_initrd)

set_source_files_properties(vmm.c PROPERTIES COMPILE_OPTIONS "-include;${BOARD_DIR}/include/microkit.h")

add_executable(vmm.elf
    vmm.c
    $<TARGET_OBJECTS:vmm_asm_obj>
)
target_compile_options(vmm.elf PRIVATE ${SEL4_C_FLAGS})
target_compile_definitions(vmm.elf PRIVATE BOARD_${MICROKIT_BOARD})
target_include_directories(vmm.elf PRIVATE "${CMAKE_SOURCE_DIR}/src")
target_link_libraries(vmm.elf PRIVATE
    stubs
    libvmm
    sddf_util_debug
    microkit_lib
    musllibc_lib
)
target_link_options(vmm.elf PRIVATE ${SEL4_LINK_FLAGS})
add_dependencies(vmm.elf dtb repack_initrd)
