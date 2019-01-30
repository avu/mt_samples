cmake_minimum_required(VERSION 3.13)
project(main)

set(CMAKE_CXX_STANDARD 17)

execute_process(COMMAND xcode-select -p
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        RESULT_VARIABLE xcode_result
        OUTPUT_VARIABLE xcode_path
        OUTPUT_STRIP_TRAILING_WHITESPACE)

set(xcode_usr_bin ${xcode_path}/Platforms/MacOSX.platform/usr/bin)

FIND_LIBRARY(APPKIT_LIBRARY AppKit)
add_executable(main main.mm)


target_link_libraries(main ${APPKIT_LIBRARY})
target_link_libraries(main "-framework Cocoa")
target_link_libraries(main "-framework Metal")
target_link_libraries(main "-framework MetalKit")
target_link_libraries(main "-framework QuartzCore")
