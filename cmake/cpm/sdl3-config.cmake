# When updating, do not forget to place java impl in sync
cpmaddpackage(
    NAME
    SDL3
    GITHUB_REPOSITORY
    libsdl-org/SDL
    VERSION
    3.4.2
    GIT_TAG
    release-3.4.2
    GIT_SHALLOW
    ON
    SYSTEM
    TRUE
    EXCLUDE_FROM_ALL
    TRUE
    GIT_PROGRESS
    TRUE
    OPTIONS
    "SDL_PRECOMPILED_HEADERS OFF"
    # ---- build type ----
    "SDL_STATIC OFF"
    "SDL_SHARED ON"
    "SDL_CCACHE ON"
    # ---- subsystems: video + events + logging only ----
    "SDL_AUDIO OFF"
    "SDL_VIDEO ON"
    "SDL_GPU ON"
    "SDL_RENDER ON"
    "SDL_CAMERA OFF"
    "SDL_JOYSTICK OFF"
    "SDL_HAPTIC OFF"
    "SDL_HIDAPI OFF"
    "SDL_POWER OFF"
    "SDL_SENSOR OFF"
    "SDL_DIALOG OFF"
    # ---- video backends: only what each platform needs ----
    "SDL_X11 OFF"
    "SDL_WAYLAND ${LINUX}" # ON only on Linux
    "SDL_KMSDRM OFF"
    "SDL_RPI OFF"
    "SDL_ROCKCHIP OFF"
    "SDL_VIVANTE OFF"
    "SDL_OFFSCREEN OFF"
    "SDL_DUMMYVIDEO OFF"
    "SDL_OPENVR OFF"
    # ---- rendering APIs: none needed for window-only ----
    "SDL_VULKAN OFF"
    "SDL_RENDER_VULKAN OFF"
    "SDL_OPENGL OFF"
    "SDL_OPENGLES OFF"
    "SDL_METAL ${APPLE}"
    "SDL_RENDER_METAL ${APPLE}"
    "SDL_RENDER_D3D OFF"
    "SDL_RENDER_D3D11 OFF"
    "SDL_RENDER_D3D12 ${WIN32}"
    "SDL_RENDER_GPU OFF"
    # ---- audio backends: all off (subsystem is off) ----
    "SDL_ALSA OFF"
    "SDL_JACK OFF"
    "SDL_PIPEWIRE OFF"
    "SDL_PULSEAUDIO OFF"
    "SDL_SNDIO OFF"
    "SDL_OSS OFF"
    "SDL_DISKAUDIO OFF"
    "SDL_DUMMYAUDIO OFF"
    # ---- input/hid: all off ----
    "SDL_HIDAPI_LIBUSB OFF"
    "SDL_HIDAPI_JOYSTICK OFF"
    "SDL_VIRTUAL_JOYSTICK OFF"
    "SDL_LIBUDEV OFF"
    # ---- misc: strip everything else ----
    "SDL_ASSEMBLY OFF"
    "SDL_DBUS ON" # needed for Wayland integration
    "SDL_IBUS ON" # IME support on Linux
    "SDL_LIBURING OFF"
    # ---- no tests/examples/install ----
    "SDL_TEST_LIBRARY OFF"
    "SDL_TESTS OFF"
    "SDL_EXAMPLES OFF"
    "SDL_INSTALL OFF"
    "SDL_INSTALL_TESTS OFF"
    "SDL_DISABLE_INSTALL_DOCS ON")

if(TARGET SDL3-shared)
    set_target_properties(SDL3-shared PROPERTIES DISABLE_PRECOMPILE_HEADERS ON)
endif()

if(APPLE AND TARGET SDL3-shared)
    target_link_options(SDL3-shared INTERFACE
                        "SHELL:-Wl,-U,___isPlatformVersionAtLeast")
endif()
