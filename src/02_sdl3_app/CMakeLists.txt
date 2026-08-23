if(NOT TARGET SDL3::SDL3-shared)
    return()
endif()

ct_add_executable(02_sdl3_app)

target_sources(02_sdl3_app PRIVATE main.cpp)

target_compile_features(02_sdl3_app PRIVATE cxx_std_23)
target_link_libraries(02_sdl3_app PRIVATE SDL3::SDL3-shared Microsoft.GSL::GSL
                                          warnings)

if(CMAKE_SYSTEM_NAME MATCHES "Android|Emscripten")
    return()
endif()

# ── RPATH: find libSDL3 at runtime after install ─────────────────────
# @executable_path on Apple, $ORIGIN elsewhere — one generator
# expression instead of a per-platform if/else. INSTALL_RPATH supports
# genexes, and CMP0095 (NEW at our 4.4 floor) escapes $ORIGIN correctly
# in the install script.
set_target_properties(
    02_sdl3_app
    PROPERTIES
        INSTALL_RPATH
        "$<IF:$<PLATFORM_ID:Darwin,iOS>,@executable_path,$ORIGIN>/../${CMAKE_INSTALL_LIBDIR}"
        BUILD_RPATH_USE_ORIGIN ON)

install(TARGETS 02_sdl3_app RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                    COMPONENT runtime)

# ── Windows: stage runtime DLLs next to the .exe for build-tree runs ─
# $<TARGET_RUNTIME_DLLS> expands to nothing on other platforms, but
# guarding keeps the custom command out of non-Windows build graphs.
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    add_custom_command(
        TARGET 02_sdl3_app
        POST_BUILD
        COMMAND
            ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:02_sdl3_app>
            $<TARGET_RUNTIME_DLLS:02_sdl3_app>
        COMMAND_EXPAND_LISTS)
endif()
