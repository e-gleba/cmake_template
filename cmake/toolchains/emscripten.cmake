# Zero-setup Emscripten toolchain: locates a usable emsdk - bootstrapping a
# pinned one into the repo-local `.emsdk/` on first configure - then defers
# to the upstream toolchain file shipped inside the SDK. No system-wide
# install and no `$HOME` pollution (`emsdk activate --embedded`); delete
# `.emsdk/` to reset.
#
# Resolution order:
#   1. `EMSDK` environment variable (existing install, e.g. CI) - used as-is
#   2. `EMSCRIPTEN_SDK_ROOT` cache entry (custom SDK location)
#   3. `<repo>/.emsdk` - downloaded and activated here on first use
#
# Knobs (pass with `-D`):
#   EMSCRIPTEN_SDK_VERSION        pinned emsdk release to bootstrap
#   EMSCRIPTEN_SDK_TARBALL_SHA256 optional integrity pin for the tarball
#
# Requires python3 on PATH (emsdk is a python tool).

set(EMSCRIPTEN_SDK_VERSION
    "6.0.7"
    CACHE STRING "emsdk release to bootstrap when none is installed")
set(EMSCRIPTEN_SDK_ROOT
    ""
    CACHE PATH "emsdk location (default: <repo>/.emsdk)")
set(EMSCRIPTEN_SDK_TARBALL_SHA256
    ""
    CACHE STRING "optional SHA256 pin for the emsdk source tarball")
mark_as_advanced(EMSCRIPTEN_SDK_TARBALL_SHA256)

# Location of the real toolchain inside any emsdk checkout, relative to its
# root. Read by the functions below through CMake's dynamic scoping.
set(emsdk_toolchain_relpath
    "upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")

# emsdk_resolve_root(<out-var>)
#
# Writes the emsdk location to <out-var> following the resolution order
# documented in the file header.
function(emsdk_resolve_root out_var)
    if(DEFINED ENV{EMSDK} AND EXISTS "$ENV{EMSDK}/${emsdk_toolchain_relpath}")
        set(root "$ENV{EMSDK}")
    elseif(EMSCRIPTEN_SDK_ROOT)
        set(root "${EMSCRIPTEN_SDK_ROOT}")
    else()
        # CMAKE_CURRENT_FUNCTION_LIST_DIR is the directory of the file that
        # DEFINES this function; CMAKE_CURRENT_LIST_DIR would be the caller's
        # directory instead. ABSOLUTE (not REALPATH) because `.emsdk` does
        # not exist yet on first configure.
        get_filename_component(
            root "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../../.emsdk" ABSOLUTE)
    endif()
    set(${out_var}
        "${root}"
        PARENT_SCOPE)
endfunction()

# emsdk_bootstrap(<root>)
#
# Downloads and activates the pinned emsdk into <root>. Every step is guarded
# by a filesystem check, so re-configures and interrupted setups resume
# instead of restarting - important because this file is re-evaluated by
# every try_compile().
function(emsdk_bootstrap root)
    find_program(
        EMSCRIPTEN_PYTHON
        NAMES python3 python
        DOC "python interpreter driving the emsdk installer")
    mark_as_advanced(EMSCRIPTEN_PYTHON)
    if(NOT EMSCRIPTEN_PYTHON)
        message(
            FATAL_ERROR
            "python3 is required to bootstrap emsdk. "
            "Install it or point EMSDK at an existing SDK.")
    endif()

    if(NOT EXISTS "${root}/emsdk.py")
        set(url
            "https://github.com/emscripten-core/emsdk/archive/refs/tags/${EMSCRIPTEN_SDK_VERSION}.tar.gz"
        )
        set(staging "${CMAKE_BINARY_DIR}/_emsdk_bootstrap")

        message(
            STATUS "Downloading emsdk ${EMSCRIPTEN_SDK_VERSION} -> ${root}")
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
        get_filename_component(parent "${root}" DIRECTORY)
        file(ARCHIVE_EXTRACT INPUT "${staging}/emsdk.tar.gz" DESTINATION
             "${parent}")
        file(REMOVE_RECURSE "${root}")
        file(RENAME "${parent}/emsdk-${EMSCRIPTEN_SDK_VERSION}" "${root}")
        file(REMOVE_RECURSE "${staging}")
    endif()

    # One-time, ~2 GB. Output flows through so CI logs show live progress.
    message(STATUS "Installing emscripten ${EMSCRIPTEN_SDK_VERSION}")
    execute_process(
        COMMAND "${EMSCRIPTEN_PYTHON}" emsdk.py install
                "${EMSCRIPTEN_SDK_VERSION}"
        WORKING_DIRECTORY "${root}"
        COMMAND_ERROR_IS_FATAL ANY)

    # --embedded keeps the `.emscripten` config inside the SDK: no $HOME
    # edits, and emcc finds it at build time without any environment.
    execute_process(
        COMMAND "${EMSCRIPTEN_PYTHON}" emsdk.py activate --embedded
                "${EMSCRIPTEN_SDK_VERSION}"
        WORKING_DIRECTORY "${root}"
        COMMAND_ERROR_IS_FATAL ANY)
endfunction()

# emsdk_use_bundled_node(<root>)
#
# ctest needs a JS runtime to execute the test suite. The upstream toolchain
# only looks for a system node; fall back to the one bundled with the emsdk.
function(emsdk_use_bundled_node root)
    if(CMAKE_CROSSCOMPILING_EMULATOR)
        return()
    endif()
    file(GLOB node "${root}/node/*/bin/node" "${root}/node/*/bin/node.exe")
    if(node)
        list(GET node 0 node)
        set(CMAKE_CROSSCOMPILING_EMULATOR
            "${node}"
            PARENT_SCOPE)
        message(STATUS "ctest emulator: ${node}")
    endif()
endfunction()

emsdk_resolve_root(sdk_root)

if(NOT EXISTS "${sdk_root}/${emsdk_toolchain_relpath}")
    emsdk_bootstrap("${sdk_root}")
endif()
if(NOT EXISTS "${sdk_root}/${emsdk_toolchain_relpath}")
    message(
        FATAL_ERROR
        "emsdk at '${sdk_root}' is incomplete - delete it and re-configure")
endif()

# Configure-time env for compiler detection; at build time emcc locates the
# embedded config on its own.
set(ENV{EMSDK} "${sdk_root}")
set(ENV{EM_CONFIG} "${sdk_root}/.emscripten")

include("${sdk_root}/${emsdk_toolchain_relpath}")

emsdk_use_bundled_node("${sdk_root}")
