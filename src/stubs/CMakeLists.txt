# Stubs for seL4 protection domains
add_library(stubs STATIC
    emutls.c
    errno.c
    syscalls.c
    clock.c
)

target_link_libraries(stubs PRIVATE musllibc_lib)
target_include_directories(stubs PRIVATE "${BOARD_DIR}/include")
target_compile_options(stubs PRIVATE ${SEL4_C_FLAGS})
target_compile_definitions(stubs PRIVATE BOARD_${MICROKIT_BOARD})
