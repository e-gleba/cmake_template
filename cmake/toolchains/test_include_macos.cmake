cmake_minimum_required(VERSION 3.31)

set(CMAKE_SYSTEM_NAME "Darwin")
set(CMAKE_SYSTEM_PROCESSOR "x86_64")

# ---- Configuration (override via -D or preset cacheVariables) ----
set(OSXCROSS_SDK_VERSION
    "15.2"
    CACHE STRING "macOS SDK version")
set(OSXCROSS_DEPLOY_TARGET
    "13.5"
    CACHE STRING "Minimum macOS deployment target")
set(OSXCROSS_DARWIN_TARGET
    "darwin24.2"
    CACHE STRING "Darwin target suffix")
set(OSXCROSS_DIR
    "${CMAKE_BINARY_DIR}/_osxcross"
    CACHE PATH "osxcross work directory")

set(OSXCROSS_SDK_URL
    "https://github.com/joseluisq/macosx-sdks/releases/download/${OSXCROSS_SDK_VERSION}/MacOSX${OSXCROSS_SDK_VERSION}.sdk.tar.xz"
    CACHE STRING "")
set(OSXCROSS_REPO_URL
    "https://github.com/tpoechtrager/osxcross.git"
    CACHE STRING "")

# ---- Derive triple ----
if(NOT CMAKE_SYSTEM_PROCESSOR)
    set(CMAKE_SYSTEM_PROCESSOR x86_64)
endif()

set(_oxc_triple "${CMAKE_SYSTEM_PROCESSOR}-apple-${OSXCROSS_DARWIN_TARGET}")
set(_oxc_target "${OSXCROSS_DIR}/target")
set(_oxc_bin "${_oxc_target}/bin")
set(_oxc_sdk "${_oxc_target}/SDK/MacOSX${OSXCROSS_SDK_VERSION}.sdk")

# ---- Already built? Cache paths and bail ----
if(EXISTS "${_oxc_bin}/${_oxc_triple}-clang")
    set(OSXCROSS_TRIPLE
        "${_oxc_triple}"
        CACHE INTERNAL "")
    set(OSXCROSS_BIN_DIR
        "${_oxc_bin}"
        CACHE INTERNAL "")
    set(OSXCROSS_SDK_DIR
        "${_oxc_sdk}"
        CACHE INTERNAL "")
    set(OSXCROSS_TARGET_DIR
        "${_oxc_target}"
        CACHE INTERNAL "")
else()
    # ---- 1. Clone ----
    if(NOT EXISTS "${OSXCROSS_DIR}/build.sh")
        message(STATUS "[osxcross] cloning repo...")
        execute_process(
            COMMAND git clone --depth 1 "${OSXCROSS_REPO_URL}" "${OSXCROSS_DIR}"
            RESULT_VARIABLE _rc)
        if(NOT
           _rc
           EQUAL
           0)
            message(FATAL_ERROR "[osxcross] git clone failed (${_rc})")
        endif()
    endif()

    # ---- 2. Download SDK ----
    set(_tarball
        "${OSXCROSS_DIR}/tarballs/MacOSX${OSXCROSS_SDK_VERSION}.sdk.tar.xz")
    if(NOT EXISTS "${_tarball}")
        file(MAKE_DIRECTORY "${OSXCROSS_DIR}/tarballs")
        message(STATUS "[osxcross] downloading SDK ${OSXCROSS_SDK_VERSION}...")
        file(
            DOWNLOAD "${OSXCROSS_SDK_URL}" "${_tarball}"
            SHOW_PROGRESS
            STATUS _st)
        list(
            GET
            _st
            0
            _rc)
        if(NOT
           _rc
           EQUAL
           0)
            list(
                GET
                _st
                1
                _msg)
            file(REMOVE "${_tarball}")
            message(FATAL_ERROR "[osxcross] download failed: ${_msg}")
        endif()
    endif()

    # ---- 3. Build ----
    message(STATUS "[osxcross] building toolchain (~5 min)...")
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E env UNATTENDED=1
            SDK_VERSION=${OSXCROSS_SDK_VERSION} OSX_VERSION_MIN=10.13
            TARGET_DIR=${_oxc_target} bash ./build.sh
        WORKING_DIRECTORY "${OSXCROSS_DIR}"
        RESULT_VARIABLE _rc)
    if(NOT
       _rc
       EQUAL
       0)
        message(FATAL_ERROR "[osxcross] build.sh failed (${_rc})")
    endif()

    if(NOT EXISTS "${_oxc_bin}/${_oxc_triple}-clang")
        message(
            FATAL_ERROR
                "[osxcross] compiler not found: ${_oxc_bin}/${_oxc_triple}-clang\n"
                "Check OSXCROSS_DARWIN_TARGET for SDK ${OSXCROSS_SDK_VERSION}.")
    endif()

    # ---- 4. Cache results ----
    set(OSXCROSS_TRIPLE
        "${_oxc_triple}"
        CACHE INTERNAL "")
    set(OSXCROSS_BIN_DIR
        "${_oxc_bin}"
        CACHE INTERNAL "")
    set(OSXCROSS_SDK_DIR
        "${_oxc_sdk}"
        CACHE INTERNAL "")
    set(OSXCROSS_TARGET_DIR
        "${_oxc_target}"
        CACHE INTERNAL "")
    message(STATUS "[osxcross] toolchain ready => ${_oxc_triple}")
endif()

# -------------------------------------------------------------------
# Cross-compilation settings
# -------------------------------------------------------------------
set(CMAKE_CROSSCOMPILING TRUE)
set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_VERSION "${OSXCROSS_SDK_VERSION}")

# ---- Compilers ----
set(CMAKE_C_COMPILER "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-clang")
set(CMAKE_CXX_COMPILER "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-clang++")
set(CMAKE_OBJC_COMPILER "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-clang")
set(CMAKE_OBJCXX_COMPILER "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-clang++")

# ---- Build tools ----
set(CMAKE_AR
    "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-ar"
    CACHE FILEPATH "")
set(CMAKE_RANLIB
    "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-ranlib"
    CACHE FILEPATH "")
set(CMAKE_INSTALL_NAME_TOOL
    "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-install_name_tool"
    CACHE FILEPATH "")
set(CMAKE_STRIP
    "${OSXCROSS_BIN_DIR}/${OSXCROSS_TRIPLE}-strip"
    CACHE FILEPATH "")

# ---- SDK / sysroot ----
set(CMAKE_OSX_SYSROOT "${OSXCROSS_SDK_DIR}")
set(CMAKE_OSX_DEPLOYMENT_TARGET "${OSXCROSS_DEPLOY_TARGET}")

# ---- Search paths ----
set(CMAKE_FIND_ROOT_PATH "${OSXCROSS_SDK_DIR}"
                         "${OSXCROSS_TARGET_DIR}/macports/pkgs/opt/local")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(_oxc_undef "-Wl,-U,___isPlatformVersionAtLeast")

# ---- Linker discovery ----
# -B<dir> (glued, no space) tells clang to search <dir> for
# subprograms (ld, as). Without this, clang falls through to
# /usr/bin/ld (GNU ld) => "unrecognised emulation mode: llvm".
set(CMAKE_C_FLAGS_INIT "-B${OSXCROSS_BIN_DIR}")
set(CMAKE_CXX_FLAGS_INIT "-B${OSXCROSS_BIN_DIR}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-B${OSXCROSS_BIN_DIR} ${_oxc_undef}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-B${OSXCROSS_BIN_DIR} ${_oxc_undef}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-B${OSXCROSS_BIN_DIR} ${_oxc_undef}")

# ---- Forward custom vars to try_compile() subprojects ----
list(
    APPEND
    CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
    OSXCROSS_TRIPLE
    OSXCROSS_BIN_DIR
    OSXCROSS_SDK_DIR
    OSXCROSS_TARGET_DIR
    OSXCROSS_SDK_VERSION
    OSXCROSS_DEPLOY_TARGET)

# ---- pkg-config (if macports used) ----
set(ENV{PKG_CONFIG_LIBDIR}
    "${OSXCROSS_TARGET_DIR}/macports/pkgs/opt/local/lib/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${OSXCROSS_TARGET_DIR}/macports/pkgs")
