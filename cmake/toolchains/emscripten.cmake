# =============================================================================
# Emscripten toolchain — locates the Emscripten SDK and delegates to its
# toolchain file. Works for both command-line and IDE-driven builds.
#
# SDK resolution order:
#   1. EMSDK environment variable (set by `emsdk activate` / emsdk_env.sh)
#   2. .emsdk/ directory at the repository root (project-local SDK)
#   3. ~/emsdk (default emsdk install location)
#
# Override the SDK version in CMakePresets.json:
#   "cacheVariables": { "EMSDK_VERSION": "4.0.10" }
# =============================================================================

if(NOT DEFINED EMSDK_VERSION)
    set(EMSDK_VERSION "latest")
endif()

# --- Locate the Emscripten SDK root -----------------------------------------

if(DEFINED ENV{EMSDK} AND EXISTS "$ENV{EMSDK}/upstream/emscripten")
    set(EMSDK_ROOT "$ENV{EMSDK}")
else()
    # CPM clones dependencies with git, so git is a hard requirement of this
    # build. Anchor the project-local SDK at the git work-tree root (not a
    # relative ../..) so the path stays correct no matter where this toolchain
    # file is moved.
    find_package(Git REQUIRED)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse --show-toplevel
        WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
        OUTPUT_VARIABLE emsdk_git_root
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE emsdk_git_rc
        ERROR_VARIABLE emsdk_git_err)
    if(NOT emsdk_git_rc EQUAL 0 OR NOT emsdk_git_root)
        message(
            FATAL_ERROR
                "git rev-parse --show-toplevel failed (rc=${emsdk_git_rc}): "
                "${emsdk_git_err}. Cannot locate the repo root for .emsdk.")
    endif()
    cmake_path(SET emsdk_git_root NORMALIZE "${emsdk_git_root}")

    if(EXISTS "${emsdk_git_root}/.emsdk/upstream/emscripten")
        set(EMSDK_ROOT "${emsdk_git_root}/.emsdk")
    elseif(EXISTS "$ENV{HOME}/emsdk/upstream/emscripten")
        set(EMSDK_ROOT "$ENV{HOME}/emsdk")
    else()
        message(
            FATAL_ERROR
            "Emscripten SDK not found.\n"
            "Searched:\n"
            "  1. EMSDK environment variable\n"
            "  2. ${emsdk_git_root}/.emsdk\n"
            "  3. $ENV{HOME}/emsdk\n"
            "Install: git clone https://github.com/emscripten-core/emsdk.git "
            ".emsdk && .emsdk/emsdk install ${EMSDK_VERSION} && "
            ".emsdk/emsdk activate ${EMSDK_VERSION}")
    endif()
endif()

# --- Delegate to the SDK's own toolchain file --------------------------------

set(EMSCRIPTEN_TOOLCHAIN_FILE
    "${EMSDK_ROOT}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
)

if(NOT EXISTS "${EMSCRIPTEN_TOOLCHAIN_FILE}")
    message(
        FATAL_ERROR
        "Emscripten toolchain file not found at:\n"
        "  ${EMSCRIPTEN_TOOLCHAIN_FILE}\n"
        "SDK root: ${EMSDK_ROOT}\n"
        "Run: emsdk install ${EMSDK_VERSION} && emsdk activate "
        "${EMSDK_VERSION}")
endif()

message(STATUS "Emscripten SDK: ${EMSDK_ROOT}")
include("${EMSCRIPTEN_TOOLCHAIN_FILE}")
