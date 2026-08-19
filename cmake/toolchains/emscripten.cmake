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

# block()/endblock() (CMake 3.25) gives this script its own variable scope:
# the bootstrap's locals stay out of the toolchain's global scope, which is
# otherwise shared with the whole project. Only the cache entries above and
# the EMSDK/EM_CONFIG environment set below escape.
block(SCOPE_FOR VARIABLES)

# Path to the upstream toolchain file, relative to the SDK root. cmake_path()
# (3.20) keeps every path operation lexical and platform-correct.
cmake_path(
    SET emsdk_toolchain_file
    NORMALIZE
    "upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")

# --- Resolve the SDK root -------------------------------------------------
# Priority: EMSDK env (existing install) > explicit cache entry > repo-local.
if(DEFINED ENV{EMSDK})
    cmake_path(SET sdk_root NORMALIZE "$ENV{EMSDK}")
elseif(EMSCRIPTEN_SDK_ROOT)
    cmake_path(SET sdk_root NORMALIZE "${EMSCRIPTEN_SDK_ROOT}")
else()
    # Anchor the default at the git work-tree root (not a relative ../../) so
    # the path stays correct no matter where this toolchain file is moved.
    find_package(Git QUIET)
    if(Git_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse --show-toplevel
            WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
            OUTPUT_VARIABLE git_root
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
    endif()
    if(NOT git_root)
        # Fallback for a source tree without git metadata (e.g. an archive).
        cmake_path(SET git_root NORMALIZE "${CMAKE_CURRENT_LIST_DIR}/../..")
    endif()
    cmake_path(SET sdk_root NORMALIZE "${git_root}/.emsdk")
endif()

cmake_path(SET sdk_toolchain NORMALIZE
           "${sdk_root}/${emsdk_toolchain_file}")

# --- Bootstrap if the toolchain file is missing ---------------------------
if(NOT EXISTS "${sdk_toolchain}")
    # FindPython3 (3.12) locates the interpreter via the standard module:
    # honours venvs, the Windows registry, and python3/python fallback, and
    # exposes Python3_EXECUTABLE + Python3_VERSION. Only the Interpreter
    # component is needed - emsdk is a pure-python tool.
    find_package(Python3 COMPONENTS Interpreter)
    if(NOT Python3_Interpreter_FOUND)
        message(
            FATAL_ERROR
            "python3 is required to bootstrap emsdk. "
            "Install it or point EMSDK at an existing SDK.")
    endif()

    if(NOT EXISTS "${sdk_root}/emsdk.py")
        set(url
            "https://github.com/emscripten-core/emsdk/archive/refs/tags/${EMSCRIPTEN_SDK_VERSION}.tar.gz"
        )
        cmake_path(SET staging NORMALIZE
                   "${CMAKE_BINARY_DIR}/_emsdk_bootstrap")

        message(
            STATUS "Downloading emsdk ${EMSCRIPTEN_SDK_VERSION} -> ${sdk_root}")
        set(download_args TLS_VERIFY ON SHOW_PROGRESS STATUS status)
        if(EMSCRIPTEN_SDK_TARBALL_SHA256)
            list(APPEND download_args EXPECTED_HASH
                 "SHA256=${EMSCRIPTEN_SDK_TARBALL_SHA256}")
        endif()
        file(DOWNLOAD "${url}" "${staging}/emsdk.tar.gz" ${download_args})
        list(GET status 0 code)
        list(GET status 1 reason)
        if(NOT code EQUAL 0)
            file(REMOVE_RECURSE "${staging}")
            message(FATAL_ERROR "emsdk download failed: ${reason}")
        endif()

        # Extract next to the target so the rename stays on one filesystem.
        cmake_path(GET sdk_root PARENT_PATH sdk_parent)
        file(ARCHIVE_EXTRACT INPUT "${staging}/emsdk.tar.gz" DESTINATION
             "${sdk_parent}")
        file(REMOVE_RECURSE "${sdk_root}")
        file(RENAME "${sdk_parent}/emsdk-${EMSCRIPTEN_SDK_VERSION}"
             "${sdk_root}")
        file(REMOVE_RECURSE "${staging}")
    endif()

    # One-time, ~2 GB. ECHO_OUTPUT_VARIABLE/ECHO_ERROR_VARIABLE (3.18) stream
    # the installer's stdout/stderr through to the configure log so CI shows
    # live progress instead of a silent hang.
    message(STATUS "Installing emscripten ${EMSCRIPTEN_SDK_VERSION}")
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" emsdk.py install
                "${EMSCRIPTEN_SDK_VERSION}"
        WORKING_DIRECTORY "${sdk_root}"
        ECHO_OUTPUT_VARIABLE ECHO_ERROR_VARIABLE
        COMMAND_ERROR_IS_FATAL ANY)

    # --embedded keeps the `.emscripten` config inside the SDK: no $HOME
    # edits, and emcc finds it at build time without any environment.
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" emsdk.py activate --embedded
                "${EMSCRIPTEN_SDK_VERSION}"
        WORKING_DIRECTORY "${sdk_root}"
        ECHO_OUTPUT_VARIABLE ECHO_ERROR_VARIABLE
        COMMAND_ERROR_IS_FATAL ANY)
endif()

if(NOT EXISTS "${sdk_toolchain}")
    message(
        FATAL_ERROR
        "emsdk at '${sdk_root}' is incomplete - delete it and re-configure")
endif()

# Configure-time env for compiler detection; at build time emcc locates the
# embedded config on its own.
set(ENV{EMSDK} "${sdk_root}")
set(ENV{EM_CONFIG} "${sdk_root}/.emscripten")

include("${sdk_toolchain}")

# ctest needs a JS runtime to execute the test suite. The upstream toolchain
# only looks for a system node; fall back to the one bundled with the emsdk.
# find_program() searches the emsdk's node/<ver>/bin directories, then PATH.
if(NOT CMAKE_CROSSCOMPILING_EMULATOR)
    file(GLOB node_bin_dirs LIST_DIRECTORIES true "${sdk_root}/node/*/bin")
    find_program(
        EMSCRIPTEN_NODE
        NAMES node
        PATHS ${node_bin_dirs}
        NO_DEFAULT_PATH)
    if(NOT EMSCRIPTEN_NODE)
        find_program(EMSCRIPTEN_NODE NAMES node)
    endif()
    if(EMSCRIPTEN_NODE)
        # Propagate out of the block() scope so ctest sees it.
        set(CMAKE_CROSSCOMPILING_EMULATOR
            "${EMSCRIPTEN_NODE}"
            PARENT_SCOPE)
    endif()
endif()

# --- Summary --------------------------------------------------------------
include(CMakePrintHelpers)
cmake_print_variables(sdk_root sdk_toolchain CMAKE_CROSSCOMPILING_EMULATOR)

endblock()
