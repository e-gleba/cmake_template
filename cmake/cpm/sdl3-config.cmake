block(
    PROPAGATE
    sdl_sensor
    sdl_wayland
    sdl_dbus
    sdl_ibus
    sdl_libdecor
    sdl_opengles
    sdl_shared
    sdl_static)
# Only mobile builds need the sensor subsystem
set(sdl_sensor OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    set(sdl_sensor ON)
endif()

# Wayland + desktop integration are Linux-only
set(sdl_wayland OFF)
set(sdl_dbus OFF)
set(sdl_ibus OFF)
set(sdl_libdecor OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(sdl_wayland ON)
    set(sdl_dbus ON)
    set(sdl_ibus ON)
    set(sdl_libdecor ON)
endif()

# Disable OpenGL ES on Apple platforms (desktop GL is used instead)
set(sdl_opengles ON)
if(CMAKE_SYSTEM_NAME MATCHES "Darwin|iOS")
    set(sdl_opengles OFF)
endif()

# Emscripten has no dynamic linking — build SDL3 static-only there
set(sdl_shared ON)
set(sdl_static OFF)
if(EMSCRIPTEN)
    set(sdl_shared OFF)
    set(sdl_static ON)
endif()
endblock()

# -------------------------------------------------------------------
# Fetch SDL3: windowing, events, OpenGL context creation only
# -------------------------------------------------------------------
cpmaddpackage(
    NAME
    SDL3
    GITHUB_REPOSITORY
    libsdl-org/SDL
    VERSION
    3.4.14
    GIT_TAG
    release-3.4.14
    GIT_SHALLOW
    ON
    GIT_PROGRESS
    ON
    EXCLUDE_FROM_ALL
    TRUE
    SYSTEM
    TRUE
    OPTIONS
    # ---- build tooling ----
    "SDL_CCACHE ON"
    # ---- library type ----
    "SDL_STATIC ${sdl_static}"
    "SDL_SHARED ${sdl_shared}"
    # ---- core subsystems ----
    "SDL_AUDIO OFF"
    "SDL_VIDEO ON"
    "SDL_GPU OFF"
    "SDL_RENDER OFF"
    "SDL_CAMERA OFF"
    "SDL_JOYSTICK OFF"
    "SDL_HAPTIC OFF"
    "SDL_HIDAPI OFF"
    "SDL_POWER OFF"
    "SDL_SENSOR ${sdl_sensor}"
    # ---- video backends ----
    "SDL_X11 ON"
    "SDL_WAYLAND ${sdl_wayland}"
    "SDL_KMSDRM OFF"
    "SDL_RPI OFF"
    "SDL_ROCKCHIP OFF"
    "SDL_VIVANTE OFF"
    "SDL_DUMMYVIDEO OFF"
    "SDL_OFFSCREEN OFF"
    "SDL_OPENVR OFF"
    # ---- context APIs ----
    "SDL_OPENGL ON"
    "SDL_OPENGLES ${sdl_opengles}"
    # ---- Linux desktop integration ----
    "SDL_DBUS ${sdl_dbus}"
    "SDL_IBUS ${sdl_ibus}"
    "SDL_WAYLAND_LIBDECOR ${sdl_libdecor}"
    # ---- input / misc ----
    "SDL_LIBUDEV OFF"
    "SDL_HIDAPI_LIBUSB OFF"
    "SDL_HIDAPI_JOYSTICK OFF"
    "SDL_VIRTUAL_JOYSTICK OFF"
    # ---- tests / examples / install ----
    "SDL_TESTS OFF"
    "SDL_TEST_LIBRARY OFF"
    "SDL_EXAMPLES OFF"
    "SDL_INSTALL OFF"
    "SDL_INSTALL_TESTS OFF"
    "SDL_DISABLE_INSTALL_DOCS ON")

# -------------------------------------------------------------------
# Normalise to the standard imported target name expected by downstreams
# -------------------------------------------------------------------
if(NOT TARGET SDL3::SDL3)
    if(TARGET SDL3-shared)
        add_library(SDL3::SDL3 ALIAS SDL3-shared)
    elseif(TARGET SDL3-static)
        add_library(SDL3::SDL3 ALIAS SDL3-static)
    else()
        message(
            FATAL_ERROR "SDL3 was fetched but no linkable target exists. "
                        "Expected one of: SDL3::SDL3, SDL3-shared, SDL3-static."
        )
    endif()
endif()

# -------------------------------------------------------------------
# Android: export SDL's Java bindings for the Gradle build
# -------------------------------------------------------------------
# android-project compiles org.libsdl.app.* straight from the fetched SDL
# tree, so bumping VERSION/GIT_TAG above updates the C++ and Java sides
# atomically — no vendored Java copy to keep in sync by hand.
#
# Configure-time copy, not a build target: the Java sources are dependency
# sources (part of the fetched tree), not build artifacts, so they exist as
# soon as CPM fetches SDL. Gradle's javac then sees them with no task-order
# coupling to the native build — the previous build-time target raced AGP's
# compile*JavaWithJavac and broke CI (package org.libsdl.app does not exist).
if(CMAKE_SYSTEM_NAME STREQUAL "Android" AND TARGET SDL3-shared)
    # Anchor the destination at the git work-tree root (not a relative ../..)
    # so the path stays correct no matter where this package config is moved.
    # Same idiom as cmake/toolchains/emscripten.cmake.
    find_package(Git QUIET)
    if(Git_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse --show-toplevel
            WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
            OUTPUT_VARIABLE sdl3_repo_root
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
    endif()
    if(NOT sdl3_repo_root)
        # Fallback for a source tree without git metadata (e.g. an archive).
        cmake_path(SET sdl3_repo_root NORMALIZE
                   "${CMAKE_CURRENT_LIST_DIR}/../..")
    endif()

    set(sdl3_java_src
        "$<TARGET_PROPERTY:SDL3-shared,SOURCE_DIR>/android-project/app/src/main/java/org"
    )
    set(sdl3_java_dst
        "${sdl3_repo_root}/android-project/app/build/generated/sdl3-java/org")

    # file(COPY) is idempotent: re-copies only when contents differ, so a
    # re-configure after an SDL version bump refreshes the bindings.
    file(
        COPY "${sdl3_java_src}/"
        DESTINATION "${sdl3_java_dst}"
        FILES_MATCHING
        PATTERN "*.java")
    message(
        STATUS "Exported SDL3 Java bindings -> ${sdl3_java_dst} "
               "(sdl3 ${sdl3_VERSION})")
endif()
