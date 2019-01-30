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
        COMMAND ${xcode_usr_bin}/metal -O2 -std=osx-metal1.1 -o mpr.air
        ${CMAKE_SOURCE_DIR}/ex4_mpr/mpr.metal
        COMMAND ${xcode_usr_bin}/metal-ar r mpr.metal-ar mpr.air
        COMMAND ${xcode_usr_bin}/metallib -o mpr.metallib_ mpr.metal-ar
        COMMAND ${CMAKE_COMMAND} -E copy mpr.metallib_ mpr.metallib
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/ex_res/earth.png ${PROJECT_BINARY_DIR}/earth.png
        MAIN_DEPENDENCY mpr.metal
        VERBATIM
)