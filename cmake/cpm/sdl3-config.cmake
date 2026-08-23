# SDL3 package config — reached via find_package(sdl3 CONFIG ...), which
# cmake/cpm.cmake routes here through CMAKE_PREFIX_PATH. Fetches SDL3 with
# CPM and exposes SDL's own targets; nothing is re-named or re-exported:
#   SDL3::SDL3          - shared, or static where shared is unavailable
#   SDL3::SDL3-shared   - shared library (SDL_SHARED ON)
#   SDL3::SDL3-static   - static library (SDL_STATIC ON)
# All three aliases are created by SDL's own CMakeLists.

# A second find_package(sdl3) from another directory scope re-includes
# this file; CPM dedups the fetch itself, everything below runs once.
include_guard(GLOBAL)

# --- platform-conditional subsystems --------------------------------------
# Defaults first, per-platform overrides after; values feed OPTIONS below.
set(sdl_sensor OFF)    # only mobile builds need the sensor subsystem
set(sdl_wayland OFF)   # Linux desktop integration:
set(sdl_dbus OFF)      #   Wayland, D-Bus, IBus, libdecor
set(sdl_ibus OFF)
set(sdl_libdecor OFF)
set(sdl_opengles ON)   # Apple platforms use desktop GL instead of ES
set(sdl_shared ON)     # Emscripten has no dynamic linking: static-only
set(sdl_static OFF)

if(ANDROID)
    set(sdl_sensor ON)
endif()
if(LINUX)
    set(sdl_wayland ON)
    set(sdl_dbus ON)
    set(sdl_ibus ON)
    set(sdl_libdecor ON)
endif()
if(CMAKE_SYSTEM_NAME MATCHES "Darwin|iOS")
    set(sdl_opengles OFF)
endif()
if(EMSCRIPTEN)
    set(sdl_shared OFF)
    set(sdl_static ON)
endif()

# --------------------------------------------------------------------------
# Fetch SDL3: windowing, events, OpenGL context creation only
# --------------------------------------------------------------------------
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
    # SDL is vetted third-party code built in-tree: never let its own
    # warnings become errors in our build.
    "SDL_WERROR OFF"
    # SDL's precompiled header breaks incremental Android Studio builds:
    # the .pch is generated once per build tree and goes stale on partial
    # rebuilds ("unable to read PCH file"). Negligible cost for a dep.
    "SDL_PCH OFF"
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

# --------------------------------------------------------------------------
# Silence warnings from SDL's own compilation. SDL arms its targets with
# an aggressive flag set (SDL_AddCommonCompilerFlags: -Wall -Wundef
# -Wfloat-conversion -Wdocumentation -Wshadow ...), and any compiler newer
# than SDL's CI matrix finds something to say.
#
# No CPM-level switch does this: SYSTEM TRUE above only marks SDL's
# *interface* includes as system for *consuming* translation units —
# warnings raised while compiling SDL's own sources are unaffected.
# Inhibit warnings on SDL's compile-bearing targets directly; SDL's
# self-warnings are not actionable in this build.
#
# Guarded on SDL3_SOURCE_DIR: only a CPM-fetched SDL compiles anything.
# A system-provided SDL3 (CPM_USE_LOCAL_PACKAGES) is imported and needs
# nothing. Targets are enumerated from the fetched tree itself, so SDL
# adding or renaming targets in a future bump stays covered; INTERFACE
# and UTILITY targets compile no sources and are skipped.
# --------------------------------------------------------------------------
if(SDL3_SOURCE_DIR)
    get_property(sdl3_targets DIRECTORY "${SDL3_SOURCE_DIR}"
                 PROPERTY BUILDSYSTEM_TARGETS)
    foreach(sdl3_target IN LISTS sdl3_targets)
        get_target_property(sdl3_target_type ${sdl3_target} TYPE)
        if(NOT sdl3_target_type MATCHES "INTERFACE_LIBRARY|UTILITY")
            target_compile_options(
                ${sdl3_target}
                PRIVATE "$<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:-w>"
                        "$<$<COMPILE_LANG_AND_ID:C,MSVC>:/w>")
        endif()
    endforeach()
endif()

# --------------------------------------------------------------------------
# Android: export SDL's Java bindings + manifest/proguard for the Gradle
# build
# --------------------------------------------------------------------------
# android-project compiles org.libsdl.app.* straight from the fetched SDL
# tree, so bumping VERSION/GIT_TAG above updates the C++ and Java sides
# atomically — no vendored Java copy to keep in sync by hand.
#
# Configure-time copy, not a build target: the Java sources are dependency
# sources (part of the fetched tree), not build artifacts, so they exist
# as soon as CPM fetches SDL. Gradle's javac then sees them with no
# task-order coupling to the native build — a build-time target raced
# AGP's compile*JavaWithJavac and broke CI (package org.libsdl.app does
# not exist).
if(ANDROID)
    # The Android app lives in the top-level project; CMAKE_SOURCE_DIR
    # names it directly — no git lookup, and it stays correct when this
    # project is itself consumed via add_subdirectory()/FetchContent.
    set(sdl3_android_gen
        "${CMAKE_SOURCE_DIR}/android-project/app/build/generated/sdl3")
    set(sdl3_java_src
        "${SDL3_SOURCE_DIR}/android-project/app/src/main/java/org")
    set(sdl3_java_dst "${sdl3_android_gen}/java/org")

    if(NOT IS_DIRECTORY "${sdl3_java_src}")
        message(
            FATAL_ERROR
                "SDL3 Java sources not found at '${sdl3_java_src}' "
                "(SDL3_SOURCE_DIR='${SDL3_SOURCE_DIR}'). "
                "CPM may not have fetched SDL3 before this block ran.")
    endif()

    # file(COPY) is idempotent: re-copies only when contents differ, so a
    # re-configure after an SDL version bump refreshes the bindings.
    file(COPY "${sdl3_java_src}/" DESTINATION "${sdl3_java_dst}"
         FILES_MATCHING PATTERN "*.java")

    # Never let javac discover an empty srcDir as a cryptic "package
    # org.libsdl.app does not exist" downstream — fail loudly here.
    file(GLOB sdl3_java_exported "${sdl3_java_dst}/libsdl/app/*.java")
    if(NOT sdl3_java_exported)
        message(
            FATAL_ERROR
                "SDL3 Java export produced no files in '${sdl3_java_dst}'. "
                "Source dir was '${sdl3_java_src}'.")
    endif()
    list(LENGTH sdl3_java_exported sdl3_java_count)
    message(
        STATUS
            "Exported ${sdl3_java_count} SDL3 Java bindings -> ${sdl3_java_dst}"
    )

    # ---- SDL's base manifest + proguard rules --------------------------
    # Ship SDL's own AndroidManifest.xml / proguard-rules.pro alongside
    # the app as the *base*; the app's files are merged over / appended
    # to them by AGP, so an SDL bump never leaves a missing permission or
    # JNI keep rule. Both are REQUIRED inputs to the Gradle build
    # (manifest.srcFile and proguardFiles point at them), so a missing
    # copy must fail loudly here rather than as AGP's "Input file does
    # not exist" downstream.
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
endif()
