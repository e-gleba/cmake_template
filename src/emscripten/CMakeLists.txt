# WebAssembly deploy target - SDL3 + OpenGL (WebGL2) + Dear ImGui demo.
#
# Entered only when configuring with the Emscripten toolchain (see the
# `emscripten` preset in CMakePresets.json), so this file stays free of
# platform conditionals. Output: `web_app.{html,js,wasm}` - a fully static
# site, deployable to any web server as-is.

add_executable(web_app main.cpp)

set_target_properties(web_app PROPERTIES SUFFIX ".html")

# imgui::sdl3_opengl3 is the SDL3+OpenGL3 Dear ImGui backend alias defined
# in cmake/cpm/imgui-config.cmake.
target_link_libraries(
    web_app
    PRIVATE warnings
            SDL3::SDL3-static
            imgui::sdl3_opengl3
            gsl::gsl)

target_link_options(
    web_app
    PRIVATE "SHELL:--shell-file ${CMAKE_CURRENT_SOURCE_DIR}/shell.html"
            -sUSE_WEBGL2=1
            -sMIN_WEBGL_VERSION=2
            -sMAX_WEBGL_VERSION=2
            -sFULL_ES3=1
            -sALLOW_MEMORY_GROWTH=1
            # extra runtime checks in debug builds only, zero release cost
            $<$<CONFIG:Debug>:-sASSERTIONS=2>
            $<$<CONFIG:Debug>:-sGL_ASSERTIONS=1>)
