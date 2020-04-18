cmake_minimum_required(VERSION 3.13)
project(txtriangle)

set(CMAKE_CXX_STANDARD 17)

add_executable(txtriangle txtng.mm txtngsh.metal)

target_link_libraries(txtriangle ${APPKIT_LIBRARY})
target_link_libraries(txtriangle "-framework Cocoa")
target_link_libraries(txtriangle "-framework Metal")
target_link_libraries(txtriangle "-framework MetalKit")
target_link_libraries(txtriangle "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/txtngsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${METAL} -o txtngsh.air ${CMAKE_SOURCE_DIR}/ex3_txtriangle/txtngsh.metal
        COMMAND ${METALLIB} -o txtngsh.metallib_ txtngsh.air
        COMMAND ${CMAKE_COMMAND} -E copy txtngsh.metallib_ txtngsh.metallib
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/ex_res/earth.png ${PROJECT_BINARY_DIR}/earth.png
        MAIN_DEPENDENCY txtngsh.metal
        VERBATIM
)