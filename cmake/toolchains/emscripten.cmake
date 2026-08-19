# Zero-setup Emscripten toolchain: locates a usable emsdk - bootstrapping a
# pinned one into the repo-local `.emsdk/` on first configure - then defers
# to the upstream toolchain file shipped inside the SDK. No system-wide
# install and no `$HOME` pollution (`emsdk activate --embedded`); delete
# `.emsdk/` to reset.
#
# Resolution order:
#   1. `EMSDK` environment variable (existing install, e.g. CI) - used as-is
#   2. `EMSCRIPTEN_SDK_ROOT` cache entry (custom SDK location)
#   3. `<git-root>/.emsdk` - downloaded and activated here on first use
#
# Knobs (pass with `-D`):
#   EMSCRIPTEN_SDK_VERSION        pinned emsdk release to bootstrap
#   EMSCRIPTEN_SDK_ROOT           custom SDK location
#   EMSCRIPTEN_SDK_TARBALL_SHA256 optional integrity pin for the tarball
#
# Requires python3 on PATH (emsdk is a python tool).
#
# NOTE: this file must NOT wrap its body in block()/endblock(). A toolchain
# file's whole job is to set CMAKE_C_COMPILER / CMAKE_SYSTEM_NAME / etc. in
# the scope CMake reads them from; the upstream Emscripten.cmake sets these
# as normal variables, and a block(SCOPE_FOR VARIABLES) would swallow them,
# silently falling back to the host compiler. Locals are kept clearly named
# instead.

set(EMSCRIPTEN_SDK_VERSION
    "6.0.7"
    CACHE STRING "emsdk release to bootstrap when none is installed")
set(EMSCRIPTEN_SDK_ROOT
    ""
    CACHE PATH "emsdk location (default: <git-root>/.emsdk)")
set(EMSCRIPTEN_SDK_TARBALL_SHA256
    ""
    CACHE STRING "optional SHA256 pin for the emsdk source tarball")
mark_as_advanced(EMSCRIPTEN_SDK_TARBALL_SHA256)

# Path to the upstream toolchain file, relative to the SDK root. cmake_path()
# (3.20) keeps every path operation lexical and platform-correct.
cmake_path(
    SET _emsdk_toolchain_rel
    NORMALIZE
    "upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")

# --- Resolve the SDK root -------------------------------------------------
# Priority: EMSDK env (existing install) > explicit cache entry > repo-local.
if(DEFINED ENV{EMSDK})
    cmake_path(SET _emsdk_root NORMALIZE "$ENV{EMSDK}")
elseif(EMSCRIPTEN_SDK_ROOT)
    cmake_path(SET _emsdk_root NORMALIZE "${EMSCRIPTEN_SDK_ROOT}")
else()
    # Anchor the default at the git work-tree root (not a relative ../../) so
    # the path stays correct no matter where this toolchain file is moved.
    find_package(Git QUIET)
    if(Git_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse --show-toplevel
            WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
            OUTPUT_VARIABLE _emsdk_git_root
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
    endif()
    if(NOT _emsdk_git_root)
        # Fallback for a source tree without git metadata (e.g. an archive).
        cmake_path(SET _emsdk_git_root NORMALIZE
                   "${CMAKE_CURRENT_LIST_DIR}/../..")
    endif()
    cmake_path(SET _emsdk_root NORMALIZE "${_emsdk_git_root}/.emsdk")
endif()

cmake_path(SET _emsdk_toolchain NORMALIZE
           "${_emsdk_root}/${_emsdk_toolchain_rel}")

# --- Bootstrap if the toolchain file is missing ---------------------------
if(NOT EXISTS "${_emsdk_toolchain}")
    # FindPython3 (3.12) locates the interpreter via the standard module:
    # honours venvs, the Windows registry, and python3/python fallback. Only
    # the Interpreter component is needed - emsdk is a pure-python tool.
    # REQUIRED makes the module fail the configure itself when absent.
    find_package(Python3 REQUIRED COMPONENTS Interpreter)

    if(NOT EXISTS "${_emsdk_root}/emsdk.py")
        set(_emsdk_url
            "https://github.com/emscripten-core/emsdk/archive/refs/tags/${EMSCRIPTEN_SDK_VERSION}.tar.gz"
        )
        cmake_path(SET _emsdk_staging NORMALIZE
                   "${CMAKE_BINARY_DIR}/_emsdk_bootstrap")

        message(
            STATUS
                "Downloading emsdk ${EMSCRIPTEN_SDK_VERSION} -> ${_emsdk_root}"
        )
        set(_emsdk_download_args TLS_VERIFY ON SHOW_PROGRESS STATUS
                                 _emsdk_status)
        if(EMSCRIPTEN_SDK_TARBALL_SHA256)
            list(APPEND _emsdk_download_args EXPECTED_HASH
                 "SHA256=${EMSCRIPTEN_SDK_TARBALL_SHA256}")
        endif()
        file(DOWNLOAD "${_emsdk_url}" "${_emsdk_staging}/emsdk.tar.gz"
             ${_emsdk_download_args})
        list(GET _emsdk_status 0 _emsdk_code)
        list(GET _emsdk_status 1 _emsdk_reason)
        if(NOT _emsdk_code EQUAL 0)
            file(REMOVE_RECURSE "${_emsdk_staging}")
            message(FATAL_ERROR "emsdk download failed: ${_emsdk_reason}")
        endif()

        # Extract next to the target so the rename stays on one filesystem.
        cmake_path(GET _emsdk_root PARENT_PATH _emsdk_parent)
        file(ARCHIVE_EXTRACT INPUT "${_emsdk_staging}/emsdk.tar.gz"
             DESTINATION "${_emsdk_parent}")
        file(REMOVE_RECURSE "${_emsdk_root}")
        file(RENAME "${_emsdk_parent}/emsdk-${EMSCRIPTEN_SDK_VERSION}"
             "${_emsdk_root}")
        file(REMOVE_RECURSE "${_emsdk_staging}")
    endif()

    # One-time, ~2 GB. COMMAND_ECHO (3.15) prints the exact command line, and
    # ECHO_OUTPUT_VARIABLE/ECHO_ERROR_VARIABLE (3.18) stream its stdout/stderr
    # through to the configure log - CI shows what ran and its live progress
    # instead of a silent hang.
    message(STATUS "Installing emscripten ${EMSCRIPTEN_SDK_VERSION}")
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" emsdk.py install
                "${EMSCRIPTEN_SDK_VERSION}"
        WORKING_DIRECTORY "${_emsdk_root}"
        COMMAND_ECHO STDOUT
        ECHO_OUTPUT_VARIABLE ECHO_ERROR_VARIABLE
        COMMAND_ERROR_IS_FATAL ANY)

    # --embedded keeps the `.emscripten` config inside the SDK: no $HOME
    # edits, and emcc finds it at build time without any environment.
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" emsdk.py activate --embedded
                "${EMSCRIPTEN_SDK_VERSION}"
        WORKING_DIRECTORY "${_emsdk_root}"
        COMMAND_ECHO STDOUT
        ECHO_OUTPUT_VARIABLE ECHO_ERROR_VARIABLE
        COMMAND_ERROR_IS_FATAL ANY)
endif()

if(NOT EXISTS "${_emsdk_toolchain}")
    message(
        FATAL_ERROR
            "emsdk at '${_emsdk_root}' is incomplete - delete it and re-configure"
    )
endif()

# Configure-time env for compiler detection; at build time emcc locates the
# embedded config on its own.
set(ENV{EMSDK} "${_emsdk_root}")
set(ENV{EM_CONFIG} "${_emsdk_root}/.emscripten")

# The upstream toolchain sets CMAKE_C_COMPILER/CMAKE_CXX_COMPILER/
# CMAKE_SYSTEM_NAME/etc. as normal variables in THIS scope - which is exactly
# the scope CMake reads toolchain settings from. Do not scope them away.
include("${_emsdk_toolchain}")

# ctest needs a JS runtime to execute the test suite. The upstream toolchain
# only looks for a system node; fall back to the one bundled with the emsdk.
# find_program() searches the emsdk's node/<ver>/bin directories, then PATH.
if(NOT CMAKE_CROSSCOMPILING_EMULATOR)
    file(GLOB _emsdk_node_bins LIST_DIRECTORIES true "${_emsdk_root}/node/*/bin")
    find_program(
        _emsdk_node
        NAMES node
        PATHS ${_emsdk_node_bins}
        NO_DEFAULT_PATH)
    if(NOT _emsdk_node)
        find_program(_emsdk_node NAMES node)
    endif()
    if(_emsdk_node)
        set(CMAKE_CROSSCOMPILING_EMULATOR "${_emsdk_node}")
    endif()
endif()

# --- Summary --------------------------------------------------------------
include(CMakePrintHelpers)
cmake_print_variables(_emsdk_root _emsdk_toolchain
                      CMAKE_CROSSCOMPILING_EMULATOR)
