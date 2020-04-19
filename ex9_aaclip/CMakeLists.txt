cmake_minimum_required(VERSION 3.13)
project(aaclip)

set(CMAKE_CXX_STANDARD 17)

add_executable(aaclip aaclip.mm aaclip.metal)

target_link_libraries(aaclip ${APPKIT_LIBRARY})
target_link_libraries(aaclip "-framework Cocoa")
target_link_libraries(aaclip "-framework Metal")
target_link_libraries(aaclip "-framework MetalKit")
target_link_libraries(aaclip "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/aaclipsh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${METAL} -o aaclipsh.air ${CMAKE_SOURCE_DIR}/ex9_aaclip/aaclip.metal
        COMMAND ${METALLIB} -o aaclipsh.metallib_ aaclipsh.air
        COMMAND ${CMAKE_COMMAND} -E copy aaclipsh.metallib_ aaclipsh.metallib
        MAIN_DEPENDENCY aaclip.metal
        VERBATIM
)