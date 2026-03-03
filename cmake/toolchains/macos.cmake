# cmake/toolchains/macos.cmake
# -------------------------------------------------------------------
# osxcross cross-compilation toolchain (Linux -> macOS).
#
# Reads OSXCROSS_* CACHE INTERNAL variables set by the bootstrap
# script (cmake/osxcross-bootstrap.cmake). All paths come from the
# cache, so try_compile() re-reads are free — no downloads, no
# builds, no recursion.
# -------------------------------------------------------------------
cmake_minimum_required(VERSION 3.31)

set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_VERSION "${OSXCROSS_SDK_VERSION}")

if(NOT CMAKE_SYSTEM_PROCESSOR)
    set(CMAKE_SYSTEM_PROCESSOR x86_64)
endif()

# ---- PATH: osxcross wrappers resolve ld via PATH lookup ----
# Without this, clang falls through to /usr/bin/ld (GNU ld) which
# chokes on "-m llvm" because it only knows ELF emulations.
set(ENV{PATH} "${OSXCROSS_BIN_DIR}:$ENV{PATH}")

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
