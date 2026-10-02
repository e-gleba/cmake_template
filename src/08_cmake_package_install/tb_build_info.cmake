# tb_add_build_info(): bake configure-time build metadata into a target.
# Generates <OUT_DIR>/<TARGET>.cpp from TEMPLATE via configure_file(@ONLY)
# and adds it to TARGET. Every @tb_*@ placeholder used by the template is
# set here — no dead variables, no fetched dependencies (fmt is header-only).
#
#   tb_add_build_info(TARGET <t> TEMPLATE <in> OUT_DIR <dir>)
# Target must already exist. Generated file lands in the binary tree only.
function(tb_add_build_info)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "TARGET;TEMPLATE;OUT_DIR" "")

    if(arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "tb_add_build_info: unparsed arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()
    foreach(tb_key IN ITEMS TARGET TEMPLATE OUT_DIR)
        if(NOT arg_${tb_key})
            message(FATAL_ERROR "tb_add_build_info: ${tb_key} required")
        endif()
    endforeach()
    if(NOT TARGET ${arg_TARGET})
        message(FATAL_ERROR "tb_add_build_info: TARGET does not exist, create it before calling")
    endif()
    if(NOT EXISTS "${arg_TEMPLATE}")
        message(FATAL_ERROR "tb_add_build_info: TEMPLATE not found: ${arg_TEMPLATE}")
    endif()

    find_package(Git QUIET)
    set(tb_git_dirty "clean")
    if(Git_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
            WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
            OUTPUT_VARIABLE tb_git_sha
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" diff --quiet
            WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
            RESULT_VARIABLE tb_dirty_code
            ERROR_QUIET)
        if(tb_dirty_code EQUAL 1)
            set(tb_git_dirty "dirty")
        endif()
    endif()

    string(TIMESTAMP tb_timestamp_utc "%Y-%m-%dT%H:%M:%SZ" UTC)

    set(tb_project_name "${PROJECT_NAME}")
    set(tb_project_version "${PROJECT_VERSION}")
    set(tb_cmake_version "${CMAKE_VERSION}")
    set(tb_generator "${CMAKE_GENERATOR}")

    # Single-config (Make/Ninja) sets CMAKE_BUILD_TYPE; Ninja Multi-Config
    # leaves it empty — report that honestly instead of "n/a".
    if(CMAKE_BUILD_TYPE)
        set(tb_build_type "${CMAKE_BUILD_TYPE}")
    else()
        set(tb_build_type "Multi-Config")
    endif()

    set(tb_crosscompiling "${CMAKE_CROSSCOMPILING}")
    set(tb_install_prefix "${CMAKE_INSTALL_PREFIX}")
    set(tb_sysroot "${CMAKE_SYSROOT}")

    set(tb_compiler_path "${CMAKE_CXX_COMPILER}")
    # Driver facts straight from CMake's compiler detection — ground truth,
    # never inferred from IDs. Empties become "n/a" in the pass below.
    set(tb_compiler_frontend "${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}")
    # No ccache/sccache-style launcher configured → "n/a", via the same pass.
    set(tb_compiler_launcher "${CMAKE_CXX_COMPILER_LAUNCHER}")
    string(STRIP "${CMAKE_CXX_SIMULATE_ID} ${CMAKE_CXX_SIMULATE_VERSION}" tb_compiler_simulate)

    # Native builds leave CMAKE_CXX_COMPILER_TARGET empty — ask the driver
    # itself for its default triple instead of reporting a bare "n/a".
    # No hardcoded triples: whatever ${CMAKE_CXX_COMPILER} prints wins.
    set(tb_compiler_target "${CMAKE_CXX_COMPILER_TARGET}")
    if(NOT tb_compiler_target)
        # Clang answers -print-target-triple, GCC answers -dumpmachine.
        foreach(tb_flag IN ITEMS -print-target-triple -dumpmachine)
            execute_process(
                COMMAND "${CMAKE_CXX_COMPILER}" "${tb_flag}"
                OUTPUT_VARIABLE tb_probe
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET
                RESULT_VARIABLE tb_probe_result)
            if(tb_probe_result EQUAL 0 AND tb_probe)
                string(REGEX MATCH "[^\n]*" tb_compiler_target "${tb_probe}")
                break()
            endif()
        endforeach()
    endif()

    # What the link driver pulls in behind our back. ;-lists straight from
    # CMake's compiler detection — printed with a ranges splitter on the
    # C++ side, so no counting code here.
    set(tb_cxx_link_libs "${CMAKE_CXX_IMPLICIT_LINK_LIBRARIES}")
    set(tb_cxx_link_dirs "${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}")

    # Anything still empty was absent on this toolchain. The value is
    # read into a plain name first: nested expansion inside if() resets
    # non-empty values (verified), plain-name truthiness is policy-proof.
    foreach(tb_var IN ITEMS tb_git_sha tb_sysroot tb_compiler_frontend tb_compiler_launcher
                            tb_compiler_simulate tb_compiler_target)
        set(tb_val "${${tb_var}}")
        if(NOT tb_val)
            set(${tb_var} "n/a")
        endif()
    endforeach()

    file(MAKE_DIRECTORY "${arg_OUT_DIR}")
    set(tb_out_cpp "${arg_OUT_DIR}/${arg_TARGET}.cpp")
    configure_file("${arg_TEMPLATE}" "${tb_out_cpp}" @ONLY)

    # Generated file is not hand-written: skip clang-tidy/cpplint for it.
    # Hand-written sources (main.cpp, build_info.hpp) are still linted.
    set_source_files_properties("${tb_out_cpp}" PROPERTIES SKIP_LINTING ON)

    target_sources(${arg_TARGET} PRIVATE "${tb_out_cpp}")
    target_compile_features(${arg_TARGET} PRIVATE cxx_std_20)
endfunction()
