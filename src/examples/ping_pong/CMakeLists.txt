# ping_pong — builds the ping-pong protection-domain ELF and loader image

add_library(microkit_lib STATIC IMPORTED GLOBAL)
set_property(TARGET microkit_lib PROPERTY
    IMPORTED_LOCATION "${BOARD_DIR}/lib/libmicrokit.a")
set_property(TARGET microkit_lib PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${BOARD_DIR}/include")

add_executable(ping_pong_component.elf ping_pong.c)
set_property(SOURCE ping_pong.c PROPERTY
    OBJECT_DEPENDS "${UROS_OUTPUT_LIB}"
)
target_compile_options(ping_pong_component.elf PRIVATE ${SEL4_C_FLAGS})
target_compile_definitions(ping_pong_component.elf PRIVATE
    BUILD_CUSTOM_TRANSPORT
    BOARD_${MICROKIT_BOARD}
)
target_include_directories(ping_pong_component.elf PRIVATE "${CMAKE_SOURCE_DIR}/src")
target_link_libraries(ping_pong_component.elf PRIVATE
    microros_lib
    stubs
    microkit_lib
    musllibc_lib
)
target_link_options(ping_pong_component.elf PRIVATE ${SEL4_LINK_FLAGS})
add_dependencies(ping_pong_component.elf microros_lib)

set(MICROKIT_TOOL "${MICROKIT_SDK}/bin/microkit")
set(SYSTEM_FILE "${CMAKE_SOURCE_DIR}/src/examples/ping_pong/ping_pong.xml")
set(LOADER_IMG  "${CMAKE_CURRENT_BINARY_DIR}/loader.img")
set(REPORT_FILE "${CMAKE_CURRENT_BINARY_DIR}/report.txt")

add_custom_command(
    OUTPUT "${LOADER_IMG}" "${REPORT_FILE}"
    COMMAND "${MICROKIT_TOOL}" "${SYSTEM_FILE}"
        --search-path "${CMAKE_CURRENT_BINARY_DIR}"
        --search-path "${CMAKE_BINARY_DIR}/src/vmm"
        --board "${MICROKIT_BOARD}"
        --config "${MICROKIT_CONFIG}"
        -o "${LOADER_IMG}"
        -r "${REPORT_FILE}"
    DEPENDS
        ping_pong_component.elf
        vmm.elf
        "${SYSTEM_FILE}"
        "${MICROKIT_TOOL}"
    COMMENT "Generating loader image → ${LOADER_IMG}"
)

add_custom_target(loader_img ALL DEPENDS "${LOADER_IMG}" "${REPORT_FILE}")
