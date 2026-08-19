cpmaddpackage(
    NAME
    imgui
    VERSION
    1.92.7
    GITHUB_REPOSITORY
    ocornut/imgui
    EXCLUDE_FROM_ALL
    ON
    DOWNLOAD_ONLY
    TRUE)

# Idempotent: find_package(imgui) may be reached from several directory
# scopes, but the libraries below may only be defined once.
include_guard(GLOBAL)

# imgui ships no build system of its own, so its libraries are defined here:
#   imgui::imgui        - context, widgets, draw lists (platform-agnostic)
#   imgui::sdl3_opengl3 - SDL3 platform + OpenGL3 renderer backend
#
# Both are EXCLUDE_FROM_ALL: imgui is only compiled where a target actually
# links it (currently the Emscripten web_app) - native builds skip it.

add_library(imgui STATIC EXCLUDE_FROM_ALL
            ${imgui_SOURCE_DIR}/imgui.cpp
            ${imgui_SOURCE_DIR}/imgui_demo.cpp
            ${imgui_SOURCE_DIR}/imgui_draw.cpp
            ${imgui_SOURCE_DIR}/imgui_tables.cpp
            ${imgui_SOURCE_DIR}/imgui_widgets.cpp
            ${imgui_SOURCE_DIR}/misc/cpp/imgui_stdlib.cpp)
add_library(imgui::imgui ALIAS imgui)
target_include_directories(
    imgui SYSTEM
    PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}>
           $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/cpp>)
target_compile_features(imgui PUBLIC cxx_std_23)

# FreeType rasterizer is opt-in: imgui_freetype.cpp hard-includes
# <ft2build.h>, so it is only compiled when the Freetype::Freetype target
# already exists (e.g. after find_package(freetype2_upstream) - see
# cmake/cpm/freetype-config.cmake). No find_package here: the dependency is
# optional and absent on Emscripten.
if(TARGET Freetype::Freetype)
    target_sources(imgui
                   PRIVATE ${imgui_SOURCE_DIR}/misc/freetype/imgui_freetype.cpp)
    # PUBLIC because imgui_freetype.h exposes FreeType types to consumers.
    target_link_libraries(imgui PUBLIC Freetype::Freetype)
    target_include_directories(
        imgui SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/freetype>)
    target_compile_definitions(imgui PUBLIC IMGUI_ENABLE_FREETYPE)
endif()

# SDL3 + OpenGL3 renderer backend. OpenGL is linked only when its target
# already exists (desktop GL via find_package(OpenGL) elsewhere); on
# Emscripten the GLES3/WebGL2 symbols come from the emcc link flags on the
# final executable (-sUSE_WEBGL2=1 -sFULL_ES3=1), so no OpenGL target there.
if(TARGET SDL3::SDL3 AND (TARGET OpenGL::GL OR EMSCRIPTEN))
    add_library(imgui_sdl3_opengl3 STATIC EXCLUDE_FROM_ALL
                ${imgui_SOURCE_DIR}/backends/imgui_impl_sdl3.cpp
                ${imgui_SOURCE_DIR}/backends/imgui_impl_opengl3.cpp)
    add_library(imgui::sdl3_opengl3 ALIAS imgui_sdl3_opengl3)
    target_include_directories(
        imgui_sdl3_opengl3 SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/backends>)
    target_compile_features(imgui_sdl3_opengl3 PUBLIC cxx_std_23)
    # The OpenGL3 backend defaults to ES2 on Emscripten - force GLES3.
    target_compile_definitions(
        imgui_sdl3_opengl3
        PRIVATE $<$<PLATFORM_ID:Emscripten>:IMGUI_IMPL_OPENGL_ES3>)
    target_link_libraries(
        imgui_sdl3_opengl3
        PUBLIC imgui::imgui
               SDL3::SDL3
               $<$<NOT:$<PLATFORM_ID:Emscripten>>:OpenGL::GL>)
endif()
