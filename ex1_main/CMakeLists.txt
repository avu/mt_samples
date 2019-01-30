cmake_minimum_required(VERSION 3.13)
project(main)

add_executable(main main.mm)

target_link_libraries(main ${APPKIT_LIBRARY})
target_link_libraries(main "-framework Cocoa")
target_link_libraries(main "-framework Metal")
target_link_libraries(main "-framework MetalKit")
target_link_libraries(main "-framework QuartzCore")
