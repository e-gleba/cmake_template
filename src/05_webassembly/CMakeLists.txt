if(NOT EMSCRIPTEN)
    return()
endif()
# WebAssembly deploy target - SDL3 + OpenGL (WebGL2) + Dear ImGui demo.
#
# Entered only when configuring with the Emscripten toolchain (see the
# `emscripten` preset in CMakePresets.json), so this file stays free of
# platform conditionals. Output: `05_webassembly.{html,js,wasm}` - a fully static
# site, deployable to any web server as-is.

add_executable(05_webassembly main.cpp)

set_target_properties(05_webassembly PROPERTIES SUFFIX ".html")

target_compile_features(05_webassembly PRIVATE cxx_std_23)

# Target names match the rest of the project (see src/CMakeLists.txt):
#   imgui::sdl3_opengl3 - Dear ImGui SDL3+OpenGL3 backend (cmake/cpm/imgui-config.cmake)
#   Microsoft.GSL::GSL  - GSL v4.x exported alias
target_link_libraries(
    05_webassembly
    PRIVATE warnings
            SDL3::SDL3-static
            imgui::sdl3_opengl3
            Microsoft.GSL::GSL)

target_link_options(
    05_webassembly
    PRIVATE
    "SHELL:--shell-file ${CMAKE_CURRENT_LIST_DIR}/shell.html"
    -sUSE_WEBGL2=1
    -sMIN_WEBGL_VERSION=2
    -sMAX_WEBGL_VERSION=2
    -sFULL_ES3=1
    -sALLOW_MEMORY_GROWTH=1
    # extra runtime checks in debug builds, zero release cost
    "$<$<CONFIG:Debug>:-sASSERTIONS=2>"
    "$<$<CONFIG:Debug>:-sGL_ASSERTIONS=1>")
