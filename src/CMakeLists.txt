include(GNUInstallDirs)

add_executable(cli_app main.cpp)
target_compile_features(cli_app PRIVATE cxx_std_23)
target_link_libraries(cli_app PRIVATE warnings)

install(TARGETS cli_app RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                COMPONENT runtime
)

# ── WebAssembly deploy: SDL3 + OpenGL/GLES3 + Dear ImGui demo ────────
if(EMSCRIPTEN)
    add_subdirectory(emscripten)
endif()

if(NOT TARGET SDL3::SDL3-shared)
    return()
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    add_library(sdl_app SHARED sdl_main.cpp)
else()
    add_executable(sdl_app sdl_main.cpp)
endif()

target_compile_features(sdl_app PRIVATE cxx_std_23)
target_link_libraries(
    sdl_app PRIVATE SDL3::SDL3-shared Microsoft.GSL::GSL warnings
)

if(TARGET Tracy::TracyClient)
    if(CMAKE_SYSTEM_NAME STREQUAL "Android")
        add_library(tracy_sandbox SHARED tracy_sandbox.cpp)
    else()
        add_executable(tracy_sandbox tracy_sandbox.cpp)
    endif()

    target_compile_features(tracy_sandbox PRIVATE cxx_std_23)
    target_link_libraries(
        tracy_sandbox PRIVATE SDL3::SDL3-shared Tracy::TracyClient
                              Microsoft.GSL::GSL warnings
    )
endif()

if(CMAKE_SYSTEM_NAME MATCHES "Android|Emscripten")
    return()
endif()

# ── RPATH: find libSDL3 at runtime after install ─────────────────────
# @executable_path on Apple, $ORIGIN elsewhere — one generator
# expression instead of a per-platform if/else. INSTALL_RPATH supports
# genexes, and CMP0095 (NEW at our 4.4 floor) escapes $ORIGIN correctly
# in the install script.
set_target_properties(
    sdl_app
    PROPERTIES
        INSTALL_RPATH
            "$<IF:$<PLATFORM_ID:Darwin,iOS>,@executable_path,$ORIGIN>/../${CMAKE_INSTALL_LIBDIR}"
        BUILD_RPATH_USE_ORIGIN ON)

install(TARGETS sdl_app RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                COMPONENT runtime
)

# ── Windows: stage runtime DLLs next to the .exe for build-tree runs ─
# $<TARGET_RUNTIME_DLLS> expands to nothing on other platforms, but
# guarding keeps the custom command out of non-Windows build graphs.
if(WIN32)
    add_custom_command(
        TARGET sdl_app
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:sdl_app>
                $<TARGET_RUNTIME_DLLS:sdl_app>
        COMMAND_EXPAND_LISTS)
endif()

add_subdirectory(unity_build)
