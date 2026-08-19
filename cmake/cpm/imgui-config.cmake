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

# EXCLUDE_FROM_ALL: imgui is only compiled where a target actually links
# it (currently the Emscripten web_app) — native builds skip it entirely.
add_library(imgui STATIC EXCLUDE_FROM_ALL)
add_library(imgui::imgui ALIAS imgui)

target_sources(
    imgui
    PRIVATE ${imgui_SOURCE_DIR}/imgui.cpp
            ${imgui_SOURCE_DIR}/imgui_demo.cpp
            ${imgui_SOURCE_DIR}/imgui_draw.cpp
            ${imgui_SOURCE_DIR}/imgui_tables.cpp
            ${imgui_SOURCE_DIR}/imgui_widgets.cpp
            ${imgui_SOURCE_DIR}/misc/cpp/imgui_stdlib.cpp)

target_include_directories(
    imgui SYSTEM PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}>
                        $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/cpp>)

target_compile_features(imgui PUBLIC cxx_std_23)

# FreeType rasterizer is opt-in: imgui_freetype.cpp hard-includes
# <ft2build.h>, so it may only be compiled when FreeType is actually
# available (it is not in the Emscripten sysroot, for one).
find_package(Freetype QUIET)
if(Freetype_FOUND)
    if(NOT TARGET Freetype::Freetype)
        message(
            FATAL_ERROR
                "find_package(Freetype) succeeded but the imported target "
                "Freetype::Freetype is missing. Your FreeType install may be "
                "too old or its CMake config is incomplete.")
    endif()

    target_sources(imgui
                   PRIVATE ${imgui_SOURCE_DIR}/misc/freetype/imgui_freetype.cpp)

    # PUBLIC because imgui_freetype.h exposes FreeType types to consumers.
    target_link_libraries(imgui PUBLIC Freetype::Freetype)
    target_include_directories(
        imgui SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/misc/freetype>)
    target_compile_definitions(imgui PUBLIC IMGUI_ENABLE_FREETYPE)
else()
    message(
        STATUS "imgui: FreeType not found — custom font rasterizer disabled.")
endif()

# Platform packages needed:
#   Windows : vcpkg install opengl --triplet=x64-windows
#   Fedora  : sudo dnf install mesa-libGL-devel mesa-libGLU-devel
#   Arch    : sudo pacman -S mesa glu
#   Ubuntu  : sudo apt-get install libgl1-mesa-dev libglu1-mesa-dev
#   macOS   : OpenGL.framework is included in the SDK
#   Web     : no package — GLES3/WebGL2 symbols come from the emcc link
#             flags on the final executable (-sUSE_WEBGL2=1 -sFULL_ES3=1)

if(NOT EMSCRIPTEN)
    find_package(OpenGL QUIET)
endif()

if(TARGET SDL3::SDL3 AND (TARGET OpenGL::GL OR EMSCRIPTEN))
    add_library(imgui_sdl3_opengl3 STATIC EXCLUDE_FROM_ALL)
    add_library(imgui::sdl3_opengl3 ALIAS imgui_sdl3_opengl3)

    target_sources(
        imgui_sdl3_opengl3
        PRIVATE ${imgui_SOURCE_DIR}/backends/imgui_impl_sdl3.cpp
                ${imgui_SOURCE_DIR}/backends/imgui_impl_opengl3.cpp)

    # Backends include <imgui.h> and <imgui_impl_*.h>.
    # imgui::imgui already exposes ${imgui_SOURCE_DIR}; we only need the
    # backends directory here.
    target_include_directories(
        imgui_sdl3_opengl3 SYSTEM
        PUBLIC $<BUILD_INTERFACE:${imgui_SOURCE_DIR}/backends>)

    # GLES3/WebGL2 on Emscripten (the OpenGL3 backend defaults to ES2
    # there — override), system OpenGL everywhere else.
    target_link_libraries(
        imgui_sdl3_opengl3
        PUBLIC imgui::imgui SDL3::SDL3
               $<$<NOT:$<PLATFORM_ID:Emscripten>>:OpenGL::GL>)
    target_compile_definitions(
        imgui_sdl3_opengl3
        PRIVATE $<$<PLATFORM_ID:Emscripten>:IMGUI_IMPL_OPENGL_ES3>)

    target_compile_features(imgui_sdl3_opengl3 PUBLIC cxx_std_23)
else()
    if(NOT TARGET SDL3::SDL3)
        message(
            STATUS
                "imgui: SDL3::SDL3 target missing — skipping SDL3+OpenGL3 backend."
        )
    endif()
    if(NOT TARGET OpenGL::GL AND NOT EMSCRIPTEN)
        message(
            STATUS
                "imgui: OpenGL::GL target missing — skipping SDL3+OpenGL3 backend."
        )
    endif()
endif()
