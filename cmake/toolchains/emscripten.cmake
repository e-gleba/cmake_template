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

set(_upstream
    "upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")

if(DEFINED ENV{EMSDK} AND EXISTS "$ENV{EMSDK}/${_upstream}")
    set(_root "$ENV{EMSDK}")
else()
    if(EMSCRIPTEN_SDK_ROOT)
        set(_root "${EMSCRIPTEN_SDK_ROOT}")
    else()
        get_filename_component(_root "${CMAKE_CURRENT_LIST_DIR}/../../.emsdk"
                               REALPATH)
    endif()

    if(NOT EXISTS "${_root}/${_upstream}")
        find_program(_python NAMES python3 python)
        if(NOT _python)
            message(
                FATAL_ERROR
                "python3 is required to bootstrap emsdk. "
                "Install it or point EMSDK at an existing SDK.")
        endif()

        if(NOT EXISTS "${_root}/emsdk.py")
            set(_url
                "https://github.com/emscripten-core/emsdk/archive/refs/tags/${EMSCRIPTEN_SDK_VERSION}.tar.gz"
            )
            set(_stage "${CMAKE_BINARY_DIR}/_emsdk_bootstrap")
            message(STATUS
                    "Downloading emsdk ${EMSCRIPTEN_SDK_VERSION} -> ${_root}")
            if(EMSCRIPTEN_SDK_TARBALL_SHA256)
                set(_hash EXPECTED_HASH
                          "SHA256=${EMSCRIPTEN_SDK_TARBALL_SHA256}")
            endif()
            file(DOWNLOAD "${_url}" "${_stage}/emsdk.tar.gz" SHOW_PROGRESS
                 TLS_VERIFY ON STATUS _status ${_hash})
            list(GET _status 0 _code)
            if(NOT _code EQUAL 0)
                file(REMOVE_RECURSE "${_stage}")
                message(FATAL_ERROR "emsdk download failed: ${_status}")
            endif()
            # extract next to the target so the rename stays on one filesystem
            get_filename_component(_parent "${_root}" DIRECTORY)
            file(ARCHIVE_EXTRACT INPUT "${_stage}/emsdk.tar.gz" DESTINATION
                 "${_parent}")
            file(REMOVE_RECURSE "${_root}")
            file(RENAME "${_parent}/emsdk-${EMSCRIPTEN_SDK_VERSION}"
                 "${_root}")
            file(REMOVE_RECURSE "${_stage}")
        endif()

        message(
            STATUS
            "Installing emscripten ${EMSCRIPTEN_SDK_VERSION} (one-time, ~2 GB)"
        )
        execute_process(
            COMMAND "${_python}" emsdk.py install "${EMSCRIPTEN_SDK_VERSION}"
            WORKING_DIRECTORY "${_root}"
            RESULT_VARIABLE _rc)
        if(NOT _rc EQUAL 0)
            message(FATAL_ERROR
                    "emsdk install ${EMSCRIPTEN_SDK_VERSION} failed")
        endif()
        # --embedded keeps the `.emscripten` config inside the SDK: no $HOME
        # edits, and emcc finds it at build time without any environment
        execute_process(
            COMMAND "${_python}" emsdk.py activate --embedded
                    "${EMSCRIPTEN_SDK_VERSION}"
            WORKING_DIRECTORY "${_root}"
            RESULT_VARIABLE _rc)
        if(NOT _rc EQUAL 0)
            message(FATAL_ERROR
                    "emsdk activate ${EMSCRIPTEN_SDK_VERSION} failed")
        endif()
    endif()
endif()

if(NOT EXISTS "${_root}/${_upstream}")
    message(
        FATAL_ERROR
        "emsdk at '${_root}' is incomplete - delete it and re-configure")
endif()

# Configure-time env for compiler detection; at build time emcc locates the
# embedded config on its own.
set(ENV{EMSDK} "${_root}")
set(ENV{EM_CONFIG} "${_root}/.emscripten")

include("${_root}/${_upstream}")

# ctest needs a JS runtime: fall back to the node bundled with emsdk when no
# system node is on PATH.
if(NOT CMAKE_CROSSCOMPILING_EMULATOR)
    file(GLOB _node "${_root}/node/*/bin/node" "${_root}/node/*/bin/node.exe")
    if(_node)
        list(GET _node 0 _node)
        set(CMAKE_CROSSCOMPILING_EMULATOR "${_node}")
    endif()
endif()
