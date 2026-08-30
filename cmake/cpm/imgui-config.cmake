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

# Canonical reusable ImGui target. This is the portable upstream core plus
# imgui_stdlib; consumers can copy this config without inheriting this
# template's renderer choices.
add_library(
    imgui STATIC EXCLUDE_FROM_ALL
    ${imgui_SOURCE_DIR}/imgui.cpp
    ${imgui_SOURCE_DIR}/imgui_demo.cpp
    ${imgui_SOURCE_DIR}/imgui_draw.cpp
    ${imgui_SOURCE_DIR}/imgui_tables.cpp
    ${imgui_SOURCE_DIR}/imgui_widgets.cpp
    ${imgui_SOURCE_DIR}/misc/cpp/imgui_stdlib.cpp)
add_library(imgui::imgui ALIAS imgui)
target_include_directories(
    imgui SYSTEM PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}>
                        $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/cpp>)
target_compile_features(imgui PUBLIC cxx_std_23)

# FreeType extends canonical ImGui core rather than creating a project wrapper.
if(CT_IMGUI_FREETYPE)
    find_package(freetype CONFIG REQUIRED)
    target_sources(imgui
                   PRIVATE ${imgui_SOURCE_DIR}/misc/freetype/imgui_freetype.cpp)
    target_link_libraries(imgui PUBLIC Freetype::Freetype)
    target_include_directories(
        imgui SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/freetype>)
    target_compile_definitions(imgui PUBLIC IMGUI_ENABLE_FREETYPE)
endif()

# Project-selected integration targets combine upstream ImGui with renderer
# and platform libraries, so they live under the ct:: namespace.
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
    target_link_libraries(ct_imgui_sdl3_opengl3 PUBLIC imgui::imgui SDL3::SDL3)
    if(TARGET OpenGL::GL)
        target_link_libraries(ct_imgui_sdl3_opengl3 PUBLIC OpenGL::GL)
    endif()
endif()

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
    target_link_libraries(ct_imgui_sdl3_renderer PUBLIC imgui::imgui SDL3::SDL3)
    target_compile_features(ct_imgui_sdl3_renderer PUBLIC cxx_std_23)
endif()
