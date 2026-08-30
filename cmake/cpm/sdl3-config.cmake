# SDL3 package config — find_package(sdl3 CONFIG) lands here via
# CMAKE_PREFIX_PATH. Exposes SDL's own targets unchanged:
#   SDL3::SDL3, SDL3::SDL3-shared, SDL3::SDL3-static

include_guard(GLOBAL)

option(CT_SDL_RENDER "Build SDL3 renderer subsystem" OFF)
option(CT_IMGUI_FREETYPE "Build Dear ImGui FreeType rasterizer" OFF)
option(CT_IMGUI_SDL3_OPENGL3 "Build Dear ImGui SDL3 + OpenGL3 backend" OFF)
option(CT_IMGUI_SDL3_RENDERER "Build Dear ImGui SDL3 renderer backend" OFF)

# --- platform-conditional subsystems: defaults, then overrides ------------
set(ct_sdl_sensor OFF)
set(ct_sdl_wayland OFF)
set(ct_sdl_dbus OFF)
set(ct_sdl_ibus OFF)
set(ct_sdl_libdecor OFF)
set(ct_sdl_opengles ON)
set(ct_sdl_shared ON)
set(ct_sdl_static OFF)

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    set(ct_sdl_sensor ON)
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(ct_sdl_wayland ON)
    set(ct_sdl_dbus ON)
    set(ct_sdl_ibus ON)
    set(ct_sdl_libdecor ON)
endif()
if(CMAKE_SYSTEM_NAME MATCHES "Darwin|iOS")
    set(ct_sdl_opengles OFF)
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    set(ct_sdl_shared OFF)
    set(ct_sdl_static ON)
endif()

cpmaddpackage(
    NAME SDL3
    GITHUB_REPOSITORY libsdl-org/SDL
    VERSION 3.4.14
    GIT_TAG release-3.4.14
    GIT_SHALLOW ON
    GIT_PROGRESS ON
    EXCLUDE_FROM_ALL TRUE
    SYSTEM TRUE
    OPTIONS
    "SDL_CCACHE ON"
    "SDL_WERROR OFF"
    "SDL_PCH OFF"
    "SDL_STATIC ${ct_sdl_static}"
    "SDL_SHARED ${ct_sdl_shared}"
    "SDL_AUDIO OFF"
    "SDL_VIDEO ON"
    "SDL_GPU OFF"
    "SDL_RENDER ${CT_SDL_RENDER}"
    "SDL_CAMERA OFF"
    "SDL_JOYSTICK OFF"
    "SDL_HAPTIC OFF"
    "SDL_HIDAPI OFF"
    "SDL_POWER OFF"
    "SDL_SENSOR ${ct_sdl_sensor}"
    "SDL_X11 ON"
    "SDL_WAYLAND ${ct_sdl_wayland}"
    "SDL_KMSDRM OFF"
    "SDL_RPI OFF"
    "SDL_ROCKCHIP OFF"
    "SDL_VIVANTE OFF"
    "SDL_DUMMYVIDEO OFF"
    "SDL_OFFSCREEN OFF"
    "SDL_OPENVR OFF"
    "SDL_OPENGL ON"
    "SDL_OPENGLES ${ct_sdl_opengles}"
    "SDL_DBUS ${ct_sdl_dbus}"
    "SDL_IBUS ${ct_sdl_ibus}"
    "SDL_WAYLAND_LIBDECOR ${ct_sdl_libdecor}"
    "SDL_LIBUDEV OFF"
    "SDL_HIDAPI_LIBUSB OFF"
    "SDL_HIDAPI_JOYSTICK OFF"
    "SDL_VIRTUAL_JOYSTICK OFF"
    "SDL_TESTS OFF"
    "SDL_TEST_LIBRARY OFF"
    "SDL_EXAMPLES OFF"
    "SDL_INSTALL OFF"
    "SDL_INSTALL_TESTS OFF"
    "SDL_DISABLE_INSTALL_DOCS ON")

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    set(ct_sdl3_gen
        "${CMAKE_SOURCE_DIR}/android_project/app/build/generated/sdl3")
    file(
        COPY "${SDL3_SOURCE_DIR}/android-project/app/src/main/java/org/"
        DESTINATION "${ct_sdl3_gen}/java/org"
        FILES_MATCHING
        PATTERN "*.java")
    file(
        COPY_FILE
        "${SDL3_SOURCE_DIR}/android-project/app/src/main/AndroidManifest.xml"
        "${ct_sdl3_gen}/AndroidManifest.xml"
        ONLY_IF_DIFFERENT)
    file(
        COPY_FILE
        "${SDL3_SOURCE_DIR}/android-project/app/proguard-rules.pro"
        "${ct_sdl3_gen}/proguard-rules.pro"
        ONLY_IF_DIFFERENT)
endif()
