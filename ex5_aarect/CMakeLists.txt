cmake_minimum_required(VERSION 3.13)
project(triangle)

set(CMAKE_CXX_STANDARD 17)

add_executable(aarect aarect.mm aarect.metal)

target_link_libraries(aarect ${APPKIT_LIBRARY})
target_link_libraries(aarect "-framework Cocoa")
target_link_libraries(aarect "-framework Metal")
target_link_libraries(aarect "-framework MetalKit")
target_link_libraries(aarect "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/aarect.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${METAL} -o aarect.air ${CMAKE_SOURCE_DIR}/ex5_aarect/aarect.metal
        COMMAND ${METALLIB} -o aarect.metallib_ aarect.air
        COMMAND ${CMAKE_COMMAND} -E copy aarect.metallib_ aarect.metallib
        MAIN_DEPENDENCY aarect.metal
        VERBATIM
)