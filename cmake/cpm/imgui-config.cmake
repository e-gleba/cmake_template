cpmaddpackage(
    NAME
    imgui
    VERSION
    1.92.9
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
#   ct::imgui              - context, widgets, draw lists
#   ct::imgui_sdl3_opengl3 - SDL3 platform + OpenGL3 renderer backend
#   ct::imgui_sdl3_renderer - SDL3 platform + SDL_Renderer backend
#
# All are EXCLUDE_FROM_ALL: imgui is only compiled where a target actually
# links it (currently the Emscripten web_app) - native builds skip it.

add_library(
    ct_imgui STATIC EXCLUDE_FROM_ALL
    ${imgui_SOURCE_DIR}/imgui.cpp
    ${imgui_SOURCE_DIR}/imgui_demo.cpp
    ${imgui_SOURCE_DIR}/imgui_draw.cpp
    ${imgui_SOURCE_DIR}/imgui_tables.cpp
    ${imgui_SOURCE_DIR}/imgui_widgets.cpp
    ${imgui_SOURCE_DIR}/misc/cpp/imgui_stdlib.cpp)
add_library(ct::imgui ALIAS ct_imgui)
target_include_directories(
    ct_imgui SYSTEM PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}>
                           $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/cpp>)
target_compile_features(ct_imgui PUBLIC cxx_std_23)

# FreeType rasterizer is opt-in: imgui_freetype.cpp hard-includes
# <ft2build.h>, so it is only compiled when CT_IMGUI_FREETYPE is enabled.
if(CT_IMGUI_FREETYPE)
    find_package(freetype CONFIG REQUIRED)
    target_sources(
        ct_imgui PRIVATE ${imgui_SOURCE_DIR}/misc/freetype/imgui_freetype.cpp)
    # PUBLIC because imgui_freetype.h exposes FreeType types to consumers.
    target_link_libraries(ct_imgui PUBLIC Freetype::Freetype)
    target_include_directories(
        ct_imgui SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/freetype>)
    target_compile_definitions(ct_imgui PUBLIC IMGUI_ENABLE_FREETYPE)
endif()

# SDL3 + OpenGL3 renderer backend. Built when requested; Emscripten gets
# GLES3/WebGL2 symbols from final executable link flags, while native builds
# need the standard OpenGL imported target.
if(CT_IMGUI_SDL3_OPENGL3)
    if(NOT TARGET SDL3::SDL3)
        message(FATAL_ERROR
                "CT_IMGUI_SDL3_OPENGL3 requires the SDL3::SDL3 target")
    endif()
    if(NOT EMSCRIPTEN)
        find_package(OpenGL REQUIRED)
    endif()

    add_library(
        ct_imgui_sdl3_opengl3 STATIC EXCLUDE_FROM_ALL
        ${imgui_SOURCE_DIR}/backends/imgui_impl_opengl3.cpp
        ${imgui_SOURCE_DIR}/backends/imgui_impl_sdl3.cpp)
    add_library(ct::imgui_sdl3_opengl3 ALIAS ct_imgui_sdl3_opengl3)
    target_include_directories(
        ct_imgui_sdl3_opengl3 SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/backends>)
    target_compile_features(ct_imgui_sdl3_opengl3 PUBLIC cxx_std_23)
    target_compile_definitions(
        ct_imgui_sdl3_opengl3
        PRIVATE $<$<PLATFORM_ID:Emscripten>:IMGUI_IMPL_OPENGL_ES3>)
    target_link_libraries(ct_imgui_sdl3_opengl3 PUBLIC ct::imgui SDL3::SDL3)
    if(TARGET OpenGL::GL)
        target_link_libraries(ct_imgui_sdl3_opengl3 PUBLIC OpenGL::GL)
    endif()
endif()

# SDL3 renderer backend: stock imgui_impl_sdl3 + imgui_impl_sdlrenderer3.
if(CT_IMGUI_SDL3_RENDERER)
    if(NOT CT_SDL_RENDER)
        message(FATAL_ERROR
                "CT_IMGUI_SDL3_RENDERER requires CT_SDL_RENDER=ON")
    endif()

    add_library(ct_imgui_sdl3_renderer STATIC EXCLUDE_FROM_ALL)
    add_library(ct::imgui_sdl3_renderer ALIAS ct_imgui_sdl3_renderer)
    target_sources(
        ct_imgui_sdl3_renderer
        PRIVATE ${imgui_SOURCE_DIR}/backends/imgui_impl_sdl3.cpp
                ${imgui_SOURCE_DIR}/backends/imgui_impl_sdlrenderer3.cpp)
    target_include_directories(
        ct_imgui_sdl3_renderer SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/backends>)
    target_link_libraries(ct_imgui_sdl3_renderer PUBLIC ct::imgui SDL3::SDL3)
    target_compile_features(ct_imgui_sdl3_renderer PUBLIC cxx_std_23)
endif()
