cmake_minimum_required(VERSION 3.13)
project(triangle)

set(CMAKE_CXX_STANDARD 17)

add_executable(dclip dclip.mm dclip.metal)

target_link_libraries(dclip ${APPKIT_LIBRARY})
target_link_libraries(dclip "-framework Cocoa")
target_link_libraries(dclip "-framework Metal")
target_link_libraries(dclip "-framework MetalKit")
target_link_libraries(dclip "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/dclipsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${METAL}  -o dclipsh.air ${CMAKE_SOURCE_DIR}/ex11_dclip/dclip.metal
        COMMAND ${METALLIB} -o dclipsh.metallib_ dclipsh.air
        COMMAND ${CMAKE_COMMAND} -E copy dclipsh.metallib_ dclipsh.metallib
        MAIN_DEPENDENCY dclip.metal
        VERBATIM
)