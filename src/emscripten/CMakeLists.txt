# ── web_app: SDL3 + OpenGL/GLES3 + Dear ImGui, shaders inlined ───────
# Entered only when cross-compiling with Emscripten (see parent scope).
# emcc emits a self-contained static site: web_app.{html,js,wasm}

add_executable(web_app main.cpp)

# .html suffix: emcc emits a full page (html + js + wasm)
set_target_properties(web_app PROPERTIES SUFFIX ".html")

target_compile_features(web_app PRIVATE cxx_std_23)

target_link_libraries(
    web_app PRIVATE SDL3::SDL3 imgui::sdl3_opengl3 Microsoft.GSL::GSL
                    warnings)

target_link_options(
    web_app
    PRIVATE "-sUSE_WEBGL2=1"
            "-sFULL_ES3=1"
            "-sMIN_WEBGL_VERSION=2"
            "-sMAX_WEBGL_VERSION=2"
            "-sALLOW_MEMORY_GROWTH=1"
            "--shell-file=${CMAKE_CURRENT_SOURCE_DIR}/shell.html")
