cmake_minimum_required(VERSION 3.13)
project(triangle)

set(CMAKE_CXX_STANDARD 17)

add_executable(triangle aarect.mm tngsh.metal)

target_link_libraries(triangle ${APPKIT_LIBRARY})
target_link_libraries(triangle "-framework Cocoa")
target_link_libraries(triangle "-framework Metal")
target_link_libraries(triangle "-framework MetalKit")
target_link_libraries(triangle "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/tngsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND /usr/bin/xcrun -sdk macosx metal -c -o tngsh.air
        ${CMAKE_SOURCE_DIR}/ex2_triangle/tngsh.metal
        COMMAND /usr/bin/xcrun -sdk macosx metallib -o tngsh.metallib_ tngsh.air
        COMMAND ${CMAKE_COMMAND} -E copy tngsh.metallib_ tngsh.metallib
        MAIN_DEPENDENCY tngsh.metal
        VERBATIM
)