cmake_minimum_required(VERSION 3.13)
project(txtriangle)

set(CMAKE_CXX_STANDARD 17)

execute_process(COMMAND xcode-select -p
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        RESULT_VARIABLE xcode_result
        OUTPUT_VARIABLE xcode_path
        OUTPUT_STRIP_TRAILING_WHITESPACE)

set(xcode_usr_bin ${xcode_path}/Platforms/MacOSX.platform/usr/bin)

FIND_LIBRARY(APPKIT_LIBRARY AppKit)

add_executable(txtriangle txtng.mm txtngsh.metal)

target_link_libraries(txtriangle ${APPKIT_LIBRARY})
target_link_libraries(txtriangle "-framework Cocoa")
target_link_libraries(txtriangle "-framework Metal")
target_link_libraries(txtriangle "-framework MetalKit")
target_link_libraries(txtriangle "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/txtngsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${xcode_usr_bin}/metal -O2 -std=osx-metal1.1 -o txtngsh.air
        ${CMAKE_SOURCE_DIR}/ex3_txtriangle/txtngsh.metal
        COMMAND ${xcode_usr_bin}/metal-ar r txtngsh.metal-ar txtngsh.air
        COMMAND ${xcode_usr_bin}/metallib -o txtngsh.metallib_ txtngsh.metal-ar
        COMMAND ${CMAKE_COMMAND} -E copy txtngsh.metallib_ txtngsh.metallib
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/ex_res/earth.png ${PROJECT_BINARY_DIR}/earth.png
        MAIN_DEPENDENCY txtngsh.metal
        VERBATIM
)