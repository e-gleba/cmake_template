cmake_minimum_required(VERSION 3.31)

# Skip if not targeting Darwin (safe unconditional include)
if(NOT
   CMAKE_SYSTEM_NAME
   STREQUAL
   "Darwin")
    return()
endif()

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
    return()
endif()

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
        ${CMAKE_COMMAND} -E env UNATTENDED=1 SDK_VERSION=${OSXCROSS_SDK_VERSION}
        OSX_VERSION_MIN=10.13 TARGET_DIR=${_oxc_target} bash ./build.sh
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

set(CMAKE_CROSSCOMPILING TRUE)

project(
    cxx_project
    VERSION 1.0.0
    DESCRIPTION "My awesome C/C++ project!"
    HOMEPAGE_URL "https://github.com/e-gleba/cxx-skeleton"
    LANGUAGES C CXX)

# CMAKE_CURRENT_LIST_DIR is used instead of CMAKE_SOURCE_DIR so
# that this file works correctly if the project is ever consumed
# as a subdirectory of a larger build.
# Ref: Professional CMake §8.3 "Project-relative Variables"
list(
    APPEND
    CMAKE_PREFIX_PATH
    "${CMAKE_CURRENT_LIST_DIR}/cmake"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/description"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/code_quality")

# When cross-compiling, CMAKE_FIND_ROOT_PATH_MODE_PACKAGE is
# typically set to ONLY in the toolchain file. That restricts
# find_package() to searching only under CMAKE_FIND_ROOT_PATH
# and CMAKE_SYSROOT — our local cmake/ dirs wouldn't be found.
# Adding them to CMAKE_FIND_ROOT_PATH fixes this
if(CMAKE_CROSSCOMPILING)
    list(
        APPEND
        CMAKE_FIND_ROOT_PATH
        "${CMAKE_CURRENT_LIST_DIR}/cmake"
        "${CMAKE_CURRENT_LIST_DIR}/cmake/description"
        "${CMAKE_CURRENT_LIST_DIR}/cmake/code_quality")
endif()

find_package(warnings CONFIG REQUIRED)

find_package(clang_format CONFIG REQUIRED)
find_package(clang_tidy CONFIG REQUIRED)
find_package(clang_doc CONFIG REQUIRED)
find_package(cpplint CONFIG REQUIRED)
find_package(doxygen CONFIG REQUIRED)

find_package(cpm CONFIG REQUIRED)

add_subdirectory(src)

# CTest, CPack, and install rules for top-level metadata files
# should only run when this project owns the build. If another
# project pulls us in via add_subdirectory() or FetchContent,
# it controls testing and packaging — we should not interfere.
# Ref: Professional CMake §8.3, §39 "FetchContent"
if(PROJECT_IS_TOP_LEVEL)
    # include(CTest) creates the BUILD_TESTING cache option
    # (default ON) and sets up CDash integration.
    if(NOT CMAKE_CROSSCOMPILING)
        include(CTest)
    endif()

    if(BUILD_TESTING)
        add_subdirectory(tests)
    endif()

    include(GNUInstallDirs)
    find_package(package_description CONFIG REQUIRED)

    # Append processor to system name so packages for
    # different architectures don't collide (e.g.
    # "Windows-x86_64" vs "Windows-aarch64").
    string(APPEND CPACK_SYSTEM_NAME "-${CMAKE_SYSTEM_PROCESSOR}")

    # include(CPack) must come AFTER all CPACK_* variables
    # are set — it reads them at include-time and ignores
    # any changes made afterward.
    # Ref: Professional CMake §36.1 "Packaging Basics"
    include(CPack)
endif()
