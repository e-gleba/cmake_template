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
    # SDL is a third-party dependency built in-tree via CPM: never let its
    # own warnings become errors in our build, and don't surface them.
    "SDL_WERROR OFF"
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
# Treat SDL as a system library: silence the warnings it raises when
# compiled with its own aggressive flag set (SDL_AddCommonCompilerFlags
# adds -Wall -Wundef -Wfloat-conversion -Wdocumentation -Wshadow ...).
# CPM's SYSTEM TRUE marks SDL's *interface* include dirs SYSTEM, which
# keeps SDL headers from warning in *our* TUs — but it does not stop SDL
# warning on its *own* sources. Marking the targets SYSTEM here drops
# those self-warnings from our build output.
# -------------------------------------------------------------------
foreach(sdl3_target IN ITEMS SDL3-shared SDL3-static SDL_uclibc SDL3_Headers)
    if(TARGET ${sdl3_target})
        get_target_property(sdl3_inc ${sdl3_target} INTERFACE_INCLUDE_DIRECTORIES)
        if(sdl3_inc)
            set_target_properties(${sdl3_target}
                                  PROPERTIES INTERFACE_SYSTEM_INCLUDE_DIRECTORIES
                                             "${sdl3_inc}")
        endif()
    endif()
endforeach()
unset(sdl3_target)
unset(sdl3_inc)

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
# Android: export SDL's Java bindings + manifest/proguard for the Gradle build
# -------------------------------------------------------------------
# android-project compiles org.libsdl.app.* straight from the fetched SDL
# tree, so bumping VERSION/GIT_TAG above updates the C++ and Java sides
# atomically — no vendored Java copy to keep in sync by hand.
#
# Configure-time copy, not a build target: the Java sources are dependency
# sources (part of the fetched tree), not build artifacts, so they exist as
# soon as CPM fetches SDL. Gradle's javac then sees them with no task-order
# coupling to the native build — a build-time target raced AGP's
# compile*JavaWithJavac and broke CI (package org.libsdl.app does not exist).
if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    # CPM clones SDL with git, so git is a hard requirement of this build.
    # Anchor the destination at the git work-tree root (not a relative ../..)
    # so the path stays correct no matter where this package config is moved.
    find_package(Git REQUIRED)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse --show-toplevel
        WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
        OUTPUT_VARIABLE sdl3_repo_root
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY)
    cmake_path(SET sdl3_repo_root NORMALIZE "${sdl3_repo_root}")

    # CPM exposes the fetched tree as <NAME>_SOURCE_DIR; NAME is SDL3.
    set(sdl3_java_src
        "${SDL3_SOURCE_DIR}/android-project/app/src/main/java/org")
    if(NOT IS_DIRECTORY "${sdl3_java_src}")
        message(
            FATAL_ERROR
                "SDL3 Java sources not found at '${sdl3_java_src}' "
                "(SDL3_SOURCE_DIR='${SDL3_SOURCE_DIR}'). "
                "CPM may not have fetched SDL3 before this block ran.")
    endif()

    set(sdl3_android_gen
        "${sdl3_repo_root}/android-project/app/build/generated/sdl3")
    set(sdl3_java_dst "${sdl3_android_gen}/java/org")

    # file(COPY) is idempotent: re-copies only when contents differ, so a
    # re-configure after an SDL version bump refreshes the bindings.
    file(
        COPY "${sdl3_java_src}/"
        DESTINATION "${sdl3_java_dst}"
        FILES_MATCHING
        PATTERN "*.java")

    # Verify the copy actually produced sources — never let javac discover an
    # empty srcDir as a cryptic "package does not exist" downstream.
    file(GLOB sdl3_java_exported CONFIGURE_DEPENDS
         "${sdl3_java_dst}/libsdl/app/*.java")
    list(LENGTH sdl3_java_exported sdl3_java_count)
    if(sdl3_java_count EQUAL 0)
        message(
            FATAL_ERROR
                "SDL3 Java export produced no files in '${sdl3_java_dst}'. "
                "Source dir was '${sdl3_java_src}'.")
    endif()
    message(
        STATUS
            "Exported ${sdl3_java_count} SDL3 Java bindings -> ${sdl3_java_dst}"
    )

    # ---- SDL's base manifest + proguard rules ---------------------------
    # Ship SDL's own AndroidManifest.xml / proguard-rules.pro alongside the
    # app as the *base*; the app's files are merged over / appended to them by
    # AGP, so an SDL bump never leaves a missing permission or JNI keep rule.
    # The app still owns its Activity/manifest entries and any extra keeps —
    # these are SDL's defaults, replaceable by editing the app's own files.
    # Both are REQUIRED inputs to the Gradle build (manifest.srcFile and
    # proguardFiles point at them), so a missing copy must fail loudly here
    # rather than as AGP's "Input file does not exist" downstream.
    set(sdl3_manifest_src
        "${SDL3_SOURCE_DIR}/android-project/app/src/main/AndroidManifest.xml")
    set(sdl3_proguard_src
        "${SDL3_SOURCE_DIR}/android-project/app/proguard-rules.pro")
    foreach(sdl3_base_file IN ITEMS "${sdl3_manifest_src}"
                                    "${sdl3_proguard_src}")
        if(NOT EXISTS "${sdl3_base_file}")
            message(
                FATAL_ERROR
                    "Expected SDL3 base file missing: '${sdl3_base_file}' "
                    "(SDL3_SOURCE_DIR='${SDL3_SOURCE_DIR}').")
        endif()
    endforeach()
    file(COPY "${sdl3_manifest_src}" "${sdl3_proguard_src}"
         DESTINATION "${sdl3_android_gen}")
    unset(sdl3_base_file)
endif()
