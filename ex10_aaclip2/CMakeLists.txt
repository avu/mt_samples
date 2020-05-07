cmake_minimum_required(VERSION 3.13)
project(aaclip2)

set(CMAKE_CXX_STANDARD 17)

add_executable(aaclip2 aaclip2.mm aaclip2.metal)

target_link_libraries(aaclip2 ${APPKIT_LIBRARY})
target_link_libraries(aaclip2 "-framework Cocoa")
target_link_libraries(aaclip2 "-framework Metal")
target_link_libraries(aaclip2 "-framework MetalKit")
target_link_libraries(aaclip2 "-framework QuartzCore")

add_custom_command(
        OUTPUT ${PROJECT_BINARY_DIR}/aaclip2sh.metallib_
        WORKING_DIR ${PROJECT_BINARY_DIR}
        COMMAND ${METAL} -o aaclip2sh.air ${CMAKE_SOURCE_DIR}/ex10_aaclip2/aaclip2.metal
        COMMAND ${METALLIB} -o aaclip2sh.metallib_ aaclip2sh.air
        COMMAND ${CMAKE_COMMAND} -E copy aaclip2sh.metallib_ aaclip2sh.metallib
        MAIN_DEPENDENCY aaclip2.metal
        VERBATIM
)