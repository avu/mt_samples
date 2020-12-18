cmake_minimum_required(VERSION 3.13)
project(mt_samples)

set(CMAKE_CXX_STANDARD 17)

execute_process(COMMAND xcode-select -p
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        RESULT_VARIABLE xcode_result
        OUTPUT_VARIABLE xcode_path
        OUTPUT_STRIP_TRAILING_WHITESPACE)

set(METAL /usr/bin/xcrun -sdk macosx metal -c -std=osx-metal2.0)
set(METALLIB /usr/bin/xcrun -sdk macosx metallib)
set(xcode_usr_bin ${xcode_path}/Platforms/MacOSX.platform/usr/bin)

FIND_LIBRARY(APPKIT_LIBRARY AppKit)

add_subdirectory(ex1_main)
add_subdirectory(ex2_triangle)
add_subdirectory(ex3_txtriangle)
add_subdirectory(ex4_mpr)
add_subdirectory(ex5_aarect)
add_subdirectory(ex6_mstxt)
add_subdirectory(ex7_aarect2)
add_subdirectory(ex8_clip)
add_subdirectory(ex9_aaclip)
add_subdirectory(ex10_aaclip2)
add_subdirectory(ex11_dclip)