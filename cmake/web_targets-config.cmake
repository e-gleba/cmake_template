# web_targets-config.cmake - build commands for Emscripten/WebAssembly apps.
#
# Usage:
#   find_package(web_targets CONFIG REQUIRED)
#
#   add_web_executable(<name> SHELL_FILE <path/to/shell.html>)
#   target_sources(<name> PRIVATE ...)
#
# Found through the top-level `cmake/` entry already on CMAKE_PREFIX_PATH
# (and CMAKE_FIND_ROOT_PATH for cross-compiles), exactly like cpm-config.

include_guard(GLOBAL)

# add_web_executable(<target> SHELL_FILE <path>)
#
# Creates an executable tuned for browser deployment: `.html` suffix (emcc
# emits <target>.{html,js,wasm}), the given minimal shell page, and the
# WebGL2/GLES3 link flags. The output directory is a fully static site,
# deployable to any web server as-is.
function(add_web_executable target)
    if(NOT EMSCRIPTEN)
        message(
            FATAL_ERROR
            "add_web_executable(${target}) requires the Emscripten toolchain "
            "(configure with --preset emscripten)")
    endif()

    cmake_parse_arguments(PARSE_ARGV 1 arg "" "SHELL_FILE" "")

    if(arg_UNPARSED_ARGUMENTS)
        message(
            FATAL_ERROR
            "add_web_executable(${target}): unknown arguments: "
            "${arg_UNPARSED_ARGUMENTS}")
    endif()
    if(arg_KEYWORDS_MISSING_VALUES OR NOT DEFINED arg_SHELL_FILE)
        message(
            FATAL_ERROR
            "add_web_executable(${target}): SHELL_FILE <path> is required")
    endif()

    add_executable(${target})
    set_target_properties(${target} PROPERTIES SUFFIX ".html")

    target_link_options(
        ${target}
        PRIVATE "SHELL:--shell-file ${arg_SHELL_FILE}"
                -sUSE_WEBGL2=1
                -sMIN_WEBGL_VERSION=2
                -sMAX_WEBGL_VERSION=2
                -sFULL_ES3=1
                -sALLOW_MEMORY_GROWTH=1
                # extra runtime checks in debug builds, zero release cost
                "$<$<CONFIG:Debug>:-sASSERTIONS=2>"
                "$<$<CONFIG:Debug>:-sGL_ASSERTIONS=1>")
endfunction()
