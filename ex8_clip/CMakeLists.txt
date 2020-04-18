cmake_minimum_required(VERSION 3.13)
project(triangle)

set(CMAKE_CXX_STANDARD 17)

add_executable(clip clip.mm clip.metal)

target_link_libraries(clip ${APPKIT_LIBRARY})
target_link_libraries(clip "-framework Cocoa")
target_link_libraries(clip "-framework Metal")
target_link_libraries(clip "-framework MetalKit")
target_link_libraries(clip "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/clipsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${METAL} -o clipsh.air ${CMAKE_SOURCE_DIR}/ex8_clip/clip.metal
        COMMAND ${METALLIB} -o clipsh.metallib_ clipsh.air
        COMMAND ${CMAKE_COMMAND} -E copy clipsh.metallib_ clipsh.metallib
        MAIN_DEPENDENCY clip.metal
        VERBATIM
)