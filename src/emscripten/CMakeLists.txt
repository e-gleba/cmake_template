# WebAssembly deploy target - SDL3 + OpenGL (WebGL2) + Dear ImGui demo.
#
# Entered only when configuring with the Emscripten toolchain (see the
# `emscripten` preset in CMakePresets.json), so this file stays free of
# platform conditionals. Output: `web_app.{html,js,wasm}` - a fully static
# site, deployable to any web server as-is.

find_package(web_targets CONFIG REQUIRED)

add_web_executable(web_app SHELL_FILE "${CMAKE_CURRENT_LIST_DIR}/shell.html")

target_sources(web_app PRIVATE main.cpp)

target_compile_features(web_app PRIVATE cxx_std_23)

# Target names match the rest of the project (see src/CMakeLists.txt):
#   imgui::sdl3_opengl3 - Dear ImGui SDL3+OpenGL3 backend (cmake/cpm/imgui-config.cmake)
#   Microsoft.GSL::GSL  - GSL v4.x exported alias
target_link_libraries(
    web_app
    PRIVATE warnings
            SDL3::SDL3-static
            imgui::sdl3_opengl3
            Microsoft.GSL::GSL)
