cmake_minimum_required(VERSION 3.13)
project(aarect2)

set(CMAKE_CXX_STANDARD 17)

add_executable(aarect2 aarect2.mm aarect2.metal)

target_link_libraries(aarect2 ${APPKIT_LIBRARY})
target_link_libraries(aarect2 "-framework Cocoa")
target_link_libraries(aarect2 "-framework Metal")
target_link_libraries(aarect2 "-framework MetalKit")
target_link_libraries(aarect2 "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/aarect2.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND /usr/bin/xcrun -sdk macosx metal -c -o aarect2.air
        ${CMAKE_SOURCE_DIR}/ex7_aarect2/aarect2.metal
        COMMAND /usr/bin/xcrun -sdk macosx metallib -o aarect2.metallib_ aarect2.air
        COMMAND ${CMAKE_COMMAND} -E copy aarect2.metallib_ aarect2.metallib
        MAIN_DEPENDENCY aarect2.metal
        VERBATIM
)