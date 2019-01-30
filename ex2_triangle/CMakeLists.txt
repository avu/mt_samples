cmake_minimum_required(VERSION 3.13)
project(triangle)

set(CMAKE_CXX_STANDARD 17)

execute_process(COMMAND xcode-select -p
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        RESULT_VARIABLE xcode_result
        OUTPUT_VARIABLE xcode_path
        OUTPUT_STRIP_TRAILING_WHITESPACE)

set(xcode_usr_bin ${xcode_path}/Platforms/MacOSX.platform/usr/bin)

FIND_LIBRARY(APPKIT_LIBRARY AppKit)

add_executable(triangle tng.mm tngsh.metal)

target_link_libraries(triangle ${APPKIT_LIBRARY})
target_link_libraries(triangle "-framework Cocoa")
target_link_libraries(triangle "-framework Metal")
target_link_libraries(triangle "-framework MetalKit")
target_link_libraries(triangle "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/tngsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${xcode_usr_bin}/metal -O2 -std=osx-metal1.1 -o tngsh.air
        ${CMAKE_SOURCE_DIR}/ex2_triangle/tngsh.metal
        COMMAND ${xcode_usr_bin}/metal-ar r tngsh.metal-ar tngsh.air
        COMMAND ${xcode_usr_bin}/metallib -o tngsh.metallib_ tngsh.metal-ar
        COMMAND ${CMAKE_COMMAND} -E copy tngsh.metallib_ tngsh.metallib
        MAIN_DEPENDENCY tngsh.metal
        VERBATIM
)