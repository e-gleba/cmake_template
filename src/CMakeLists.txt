include(GNUInstallDirs)

add_executable(cli_app main.cpp)
target_compile_features(cli_app PRIVATE cxx_std_23)
target_link_libraries(cli_app PRIVATE warnings)

install(TARGETS cli_app RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                COMPONENT runtime
)

# ── web_app: SDL3 + OpenGL/GLES + Dear ImGui, shaders inlined ─────────
# Builds natively (GL 3.3 core) and for the web via the emscripten preset
# (WebGL2 / GLES3). The web output is a self-contained static site:
#   build/emscripten/Release/src/web_app.{html,js,wasm}
if(TARGET imgui::sdl3_opengl3 AND NOT CMAKE_SYSTEM_NAME STREQUAL "Android")
    add_executable(web_app web_main.cpp)
    target_compile_features(web_app PRIVATE cxx_std_23)
    target_link_libraries(
        web_app PRIVATE SDL3::SDL3 imgui::sdl3_opengl3 Microsoft.GSL::GSL
                        warnings
    )

    if(EMSCRIPTEN)
        # .html suffix: emcc emits a full page (html + js + wasm)
        set_target_properties(web_app PROPERTIES SUFFIX ".html")
        target_link_options(
            web_app
            PRIVATE "-sUSE_WEBGL2=1"
                    "-sFULL_ES3=1"
                    "-sMIN_WEBGL_VERSION=2"
                    "-sMAX_WEBGL_VERSION=2"
                    "-sALLOW_MEMORY_GROWTH=1"
                    "--shell-file=${CMAKE_CURRENT_SOURCE_DIR}/web_shell.html"
        )
    endif()

    # Windows: stage DLLs next to the exe for build-tree runs
    if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.21" AND CMAKE_SYSTEM_NAME
                                                      STREQUAL "Windows"
    )
        add_custom_command(
            TARGET web_app
            POST_BUILD
            COMMAND
                ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:web_app>
                $<TARGET_RUNTIME_DLLS:web_app>
            COMMAND_EXPAND_LISTS
        )
    endif()
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

# ── RPATH: find libSDL3.so at runtime after install ──
if(CMAKE_SYSTEM_NAME MATCHES "Darwin|iOS")
    set_target_properties(
        sdl_app
        PROPERTIES INSTALL_RPATH "@executable_path/../${CMAKE_INSTALL_LIBDIR}"
                   MACOSX_RPATH ON
    )
else()
    set_target_properties(
        sdl_app PROPERTIES INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}"
                           BUILD_RPATH_USE_ORIGIN ON
    )
endif()

install(TARGETS sdl_app RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                COMPONENT runtime
)

# ── Windows: stage DLLs next to .exe for build-tree runs ──
if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.21" AND CMAKE_SYSTEM_NAME STREQUAL
                                                  "Windows"
)
    add_custom_command(
        TARGET sdl_app
        POST_BUILD
        COMMAND
            ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:sdl_app>
            $<TARGET_RUNTIME_DLLS:sdl_app>
        COMMAND_EXPAND_LISTS
    )
endif()

add_subdirectory(unity_build)
