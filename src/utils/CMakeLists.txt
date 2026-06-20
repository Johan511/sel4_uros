set(IS_PORT_OPEN_BIN "${CMAKE_CURRENT_BINARY_DIR}/is_port_open")

add_custom_target(is_port_open_target ALL
    COMMAND aarch64-linux-gnu-gcc -static -o "${IS_PORT_OPEN_BIN}" "${CMAKE_CURRENT_SOURCE_DIR}/is_port_open.c"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/is_port_open.c"
    COMMENT "Cross-compiling is_port_open for aarch64 Linux"
)
add_executable(is_port_open IMPORTED GLOBAL)
set_property(TARGET is_port_open PROPERTY IMPORTED_LOCATION "${IS_PORT_OPEN_BIN}")
