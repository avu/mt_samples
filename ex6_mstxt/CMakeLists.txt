cmake_minimum_required(VERSION 3.13)
project(txtriangle)

set(CMAKE_CXX_STANDARD 17)

add_executable(mstxt mstxt.mm mstxt.metal)

target_link_libraries(mstxt ${APPKIT_LIBRARY})
target_link_libraries(mstxt "-framework Cocoa")
target_link_libraries(mstxt "-framework Metal")
target_link_libraries(mstxt "-framework MetalKit")
target_link_libraries(mstxt "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/txtngsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND /usr/bin/xcrun -sdk macosx metal -c -o mstxt.air
        ${CMAKE_SOURCE_DIR}/ex6_mstxt/mstxt.metal
        COMMAND /usr/bin/xcrun -sdk macosx metallib -o mstxt.metallib_ mstxt.air
        COMMAND ${CMAKE_COMMAND} -E copy mstxt.metallib_ mstxt.metallib
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/ex_res/earth.png ${PROJECT_BINARY_DIR}/earth.png
        MAIN_DEPENDENCY mstxt.metal
        VERBATIM
)