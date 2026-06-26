# src/examples/CMakeLists.txt — shared transport library + all demos

add_library(microkit_lib STATIC IMPORTED GLOBAL)
set_property(TARGET microkit_lib PROPERTY
    IMPORTED_LOCATION "${BOARD_DIR}/lib/libmicrokit.a")
set_property(TARGET microkit_lib PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${BOARD_DIR}/include")

add_library(examples_common STATIC transport_common.c)
target_include_directories(examples_common PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_SOURCE_DIR}/src"
)
target_compile_options(examples_common PRIVATE ${SEL4_C_FLAGS})
target_compile_definitions(examples_common PRIVATE
    BUILD_CUSTOM_TRANSPORT
    BOARD_${MICROKIT_BOARD}
)
target_link_libraries(examples_common PUBLIC
    microros_lib
    stubs
    microkit_lib
    musllibc_lib
)

include(uros_example)

add_uros_example(ping_pong)
add_uros_example(int32_pubsub)
add_uros_example(string_pubsub)
add_uros_example(ping_uros_agent)
