# uros_example.cmake — shared function to build a micro-ROS seL4 example
#
# Usage: add_uros_example(<name>)
#
# Expects src/examples/<name>/<name>.c as the source file.
# Produces uros_app.elf and loader.img in build/src/examples/<name>/.

include_guard(GLOBAL)

function(add_uros_example name)

    add_executable(${name} ${name}/${name}.c)
    set_target_properties(${name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${name}"
        OUTPUT_NAME uros_app
        SUFFIX .elf
    )
    set_property(SOURCE ${name}/${name}.c PROPERTY
        OBJECT_DEPENDS "${UROS_OUTPUT_LIB}"
    )
    target_compile_options(${name} PRIVATE ${SEL4_C_FLAGS})
    target_compile_definitions(${name} PRIVATE
        BUILD_CUSTOM_TRANSPORT
        BOARD_${MICROKIT_BOARD}
    )
    target_link_libraries(${name} PRIVATE examples_common)
    target_link_options(${name} PRIVATE ${SEL4_LINK_FLAGS})
    add_dependencies(${name} microros_lib)

    set(MICROKIT_TOOL "${MICROKIT_SDK}/bin/microkit")
    set(SYSTEM_FILE "${CMAKE_SOURCE_DIR}/src/examples/uros_app.xml")
    set(LOADER_IMG  "${CMAKE_CURRENT_BINARY_DIR}/${name}/loader.img")
    set(REPORT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${name}/report.txt")

    add_custom_command(
        OUTPUT "${LOADER_IMG}" "${REPORT_FILE}"
        COMMAND "${MICROKIT_TOOL}" "${SYSTEM_FILE}"
            --search-path "${CMAKE_CURRENT_BINARY_DIR}/${name}"
            --search-path "${CMAKE_BINARY_DIR}/src/vmm"
            --board "${MICROKIT_BOARD}"
            --config "${MICROKIT_CONFIG}"
            -o "${LOADER_IMG}"
            -r "${REPORT_FILE}"
        DEPENDS
            ${name}
            vmm.elf
            "${SYSTEM_FILE}"
            "${MICROKIT_TOOL}"
        COMMENT "Generating loader image → ${LOADER_IMG}"
    )

    add_custom_target(${name}_loader_img ALL DEPENDS "${LOADER_IMG}" "${REPORT_FILE}")

endfunction()
