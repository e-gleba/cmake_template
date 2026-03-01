include(GNUInstallDirs)

add_executable(cli_app main.cpp)
target_compile_features(cli_app PRIVATE cxx_std_23)
target_link_libraries(cli_app PRIVATE warnings)

install(TARGETS cli_app RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                COMPONENT runtime)

if(TARGET SDL3::SDL3-shared)
    if(CMAKE_SYSTEM_NAME STREQUAL "Android")
        add_library(sdl_app SHARED sdl_main.cpp)
    else()
        add_executable(sdl_app sdl_main.cpp)
    endif()

    target_compile_features(sdl_app PRIVATE cxx_std_23)

    target_link_libraries(sdl_app PRIVATE SDL3::SDL3-shared warnings)

    # Install only on platforms with a traditional install layout.
    # Android deploys via APK, not cmake --install.
    if(NOT
       CMAKE_SYSTEM_NAME
       STREQUAL
       "Android")
        install(TARGETS sdl_app RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                        COMPONENT runtime)
    endif()
endif()
