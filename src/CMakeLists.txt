cmake_minimum_required(VERSION 3.30)

add_executable(cli_app main.cpp)
target_link_libraries(cli_app PRIVATE warnings)
set_target_properties(
    cli_app
    PROPERTIES CXX_STANDARD 23
               CXX_STANDARD_REQUIRED YES
               CXX_EXTENSIONS NO
               OUTPUT_NAME "cli_app")

install(TARGETS cli_app RUNTIME DESTINATION bin COMPONENT runtime)

if(TARGET SDL3::SDL3-shared)
    if(CMAKE_SYSTEM_NAME STREQUAL "Android")
        add_library(sdl_app SHARED sdl_main.cpp)
    else()
        add_executable(sdl_app sdl_main.cpp)
    endif()

    target_link_libraries(sdl_app PRIVATE SDL3::SDL3-shared warnings)
    set_target_properties(
        sdl_app PROPERTIES CXX_STANDARD 23 CXX_STANDARD_REQUIRED YES
                           CXX_EXTENSIONS NO)

    install(TARGETS sdl_app COMPONENT runtime)

    cpack_add_component(
        runtime
        DISPLAY_NAME "runtime"
        DESCRIPTION "template-cpp-project main (runtime component)"
        REQUIRED)
endif()
