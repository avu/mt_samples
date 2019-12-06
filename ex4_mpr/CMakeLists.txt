cmake_minimum_required(VERSION 3.13)
project(txtriangle)

set(CMAKE_CXX_STANDARD 17)

add_executable(mpr txtng.mm mpr.metal)

target_link_libraries(mpr ${APPKIT_LIBRARY})
target_link_libraries(mpr "-framework Cocoa")
target_link_libraries(mpr "-framework Metal")
target_link_libraries(mpr "-framework MetalKit")
target_link_libraries(mpr "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/mpr.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND /usr/bin/xcrun -sdk macosx metal -c -o mpr.air
        ${CMAKE_SOURCE_DIR}/ex4_mpr/mpr.metal
        COMMAND /usr/bin/xcrun -sdk macosx metallib -o mpr.metallib_ mpr.air
        COMMAND ${CMAKE_COMMAND} -E copy mpr.metallib_ mpr.metallib
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/ex_res/earth.png ${PROJECT_BINARY_DIR}/earth.png
        MAIN_DEPENDENCY mpr.metal
        VERBATIM
)