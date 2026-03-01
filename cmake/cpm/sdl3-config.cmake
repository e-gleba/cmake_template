# When updating, do not forget to place java impl in sync

# --- SDL3 option defaults (Linux) ---
set(sdl_opts
    # Library type
    "SDL_SHARED ON"
    "SDL_STATIC OFF"
    # Build tooling
    "SDL_CCACHE ON"
    "SDL_LIBC ON"
    # Kill all test/example/install bloat
    "SDL_TEST_LIBRARY OFF"
    "SDL_SYSTEM_ICONV OFF"
    "SDL_TESTS OFF"
    "SDL_EXAMPLES OFF"
    "SDL_INSTALL_TESTS OFF"
    "SDL_DISABLE_INSTALL ON"
    "SDL_DISABLE_INSTALL_DOCS ON"
    # Video
    "SDL_WAYLAND ON"
    "SDL_X11 OFF"
    "SDL_KMSDRM OFF"
    "SDL_OFFSCREEN OFF"
    # Render
    "SDL_VULKAN OFF"
    "SDL_RENDER_VULKAN OFF"
    "SDL_RENDER_GPU OFF"
    "SDL_OPENGLES OFF"
    # Audio
    "SDL_ALSA OFF"
    "SDL_JACK OFF"
    "SDL_SNDIO OFF"
    "SDL_DISKAUDIO OFF"
    "SDL_DUMMYAUDIO ON"
    "SDL_PIPEWIRE ON"
    "SDL_PULSEAUDIO ON"
    # Input
    "SDL_HAPTIC OFF"
    "SDL_SENSOR OFF"
    "SDL_HIDAPI OFF"
    "SDL_VIRTUAL_JOYSTICK OFF"
    # Misc
    "SDL_CAMERA OFF"
    "SDL_DIALOG OFF"
    "SDL_LOCALE OFF"
    "SDL_POWER OFF"
    # Platform integration
    "SDL_IBUS OFF"
    "SDL_FCITX OFF"
    # CPU
    "SDL_ASSEMBLY OFF"
    # X11 extras
    "SDL_X11_XSCRNSAVER OFF")

# --- Windows overrides ---
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    list(
        REMOVE_ITEM
        sdl_opts
        "SDL_SHARED ON"
        "SDL_STATIC OFF"
        "SDL_WAYLAND ON"
        "SDL_PIPEWIRE ON"
        "SDL_PULSEAUDIO ON"
        "SDL_DUMMYAUDIO ON")
    list(
        APPEND
        sdl_opts
        "SDL_SHARED OFF"
        "SDL_STATIC ON"
        "SDL_WAYLAND OFF"
        "SDL_PIPEWIRE OFF"
        "SDL_PULSEAUDIO OFF"
        "SDL_DUMMYAUDIO OFF"
        "SDL_IBUS OFF"
        "SDL_FCITX OFF")
endif()

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
    OPTIONS
    ${sdl_opts})
