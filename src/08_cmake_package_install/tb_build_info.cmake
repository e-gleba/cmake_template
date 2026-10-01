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
    if(NOT arg_TARGET)
        message(FATAL_ERROR "tb_add_build_info: TARGET required")
    endif()
    if(NOT arg_TEMPLATE)
        message(FATAL_ERROR "tb_add_build_info: TEMPLATE required")
    endif()
    if(NOT arg_OUT_DIR)
        message(FATAL_ERROR "tb_add_build_info: OUT_DIR required")
    endif()
    if(NOT TARGET ${arg_TARGET})
        message(FATAL_ERROR "tb_add_build_info: TARGET does not exist, create it before calling")
    endif()
    if(NOT EXISTS "${arg_TEMPLATE}")
        message(FATAL_ERROR "tb_add_build_info: TEMPLATE not found: ${arg_TEMPLATE}")
    endif()

    find_package(Git QUIET)
    set(tb_git_sha "n/a")
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
    if(NOT tb_git_sha)
        set(tb_git_sha "n/a")
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
    if(CMAKE_SYSROOT)
        set(tb_sysroot "${CMAKE_SYSROOT}")
    else()
        set(tb_sysroot "n/a")
    endif()

    set(tb_compiler_path "${CMAKE_CXX_COMPILER}")
    # Driver facts straight from CMake's compiler detection — ground truth,
    # never inferred from IDs. Empty/absent becomes "n/a".
    if(CMAKE_CXX_COMPILER_FRONTEND_VARIANT)
        set(tb_compiler_frontend "${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}")
    else()
        set(tb_compiler_frontend "n/a")
    endif()
    if(CMAKE_CXX_SIMULATE_ID)
        set(tb_compiler_simulate
            "${CMAKE_CXX_SIMULATE_ID} ${CMAKE_CXX_SIMULATE_VERSION}")
    else()
        set(tb_compiler_simulate "n/a")
    endif()
    if(CMAKE_CXX_COMPILER_LAUNCHER)
        set(tb_compiler_launcher "${CMAKE_CXX_COMPILER_LAUNCHER}")
    else()
        # No ccache/sccache-style launcher configured for this build.
        set(tb_compiler_launcher "n/a")
    endif()
    if(CMAKE_CXX_COMPILER_TARGET)
        set(tb_compiler_target "${CMAKE_CXX_COMPILER_TARGET}")
    else()
        # Native builds leave CMAKE_CXX_COMPILER_TARGET empty — ask the driver
        # itself for its default triple instead of reporting a bare "n/a".
        # Clang answers -print-target-triple, GCC answers -dumpmachine.
        # No hardcoded triples: whatever ${CMAKE_CXX_COMPILER} prints wins.
        execute_process(
            COMMAND "${CMAKE_CXX_COMPILER}" -print-target-triple
            OUTPUT_VARIABLE tb_driver_triple
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            RESULT_VARIABLE tb_triple_result)
        if(NOT tb_triple_result EQUAL 0 OR NOT tb_driver_triple)
            execute_process(
                COMMAND "${CMAKE_CXX_COMPILER}" -dumpmachine
                OUTPUT_VARIABLE tb_driver_triple
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET
                RESULT_VARIABLE tb_triple_result)
        endif()
        if(tb_triple_result EQUAL 0 AND tb_driver_triple)
            string(REGEX MATCH "[^\n]*" tb_compiler_target "${tb_driver_triple}")
        else()
            set(tb_compiler_target "n/a")
        endif()
        unset(tb_driver_triple)
        unset(tb_triple_result)
    endif()

    # What the link driver pulls in behind our back. ;-lists straight from
    # CMake's compiler detection — printed with a ranges splitter on the
    # C++ side, so no counting code here.
    set(tb_cxx_link_libs "${CMAKE_CXX_IMPLICIT_LINK_LIBRARIES}")
    set(tb_cxx_link_dirs "${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}")

    # Truthful <vector> header: ask the driver itself with the same stdlib
    # flag the target compiles with (CT_CXX_STDLIB, set by the preset —
    # never inferred here), parse its real header search list. No layout
    # hardcoding: whatever the driver prints wins. Falls back to layout
    # probes only if the query fails (e.g. MSVC-style drivers).
    if(CT_CXX_STDLIB)
        set(tb_stdlib_flag "-stdlib=${CT_CXX_STDLIB}")
    else()
        set(tb_stdlib_flag "")
    endif()
    if(WIN32)
        set(tb_null "NUL")
    else()
        set(tb_null "/dev/null")
    endif()
    unset(tb_vector_header)
    execute_process(
        COMMAND "${CMAKE_CXX_COMPILER}" ${tb_stdlib_flag} -v -E -x c++ "${tb_null}"
        OUTPUT_QUIET
        ERROR_VARIABLE tb_cc_verbose
        RESULT_VARIABLE tb_cc_result)
    if(tb_cc_result EQUAL 0)
        string(REPLACE "\n" ";" tb_cc_lines "${tb_cc_verbose}")
        set(tb_in_list FALSE)
        unset(tb_inc_dirs)
        foreach(tb_line IN LISTS tb_cc_lines)
            if(tb_line MATCHES "search starts here")
                set(tb_in_list TRUE)
            elseif(tb_line MATCHES "End of search list")
                set(tb_in_list FALSE)
            elseif(tb_in_list)
                string(STRIP "${tb_line}" tb_dir)
                string(REGEX REPLACE " \\(.*\\)$" "" tb_dir "${tb_dir}")
                if(IS_DIRECTORY "${tb_dir}")
                    list(APPEND tb_inc_dirs "${tb_dir}")
                endif()
            endif()
        endforeach()
        foreach(tb_dir IN LISTS tb_inc_dirs)
            if(EXISTS "${tb_dir}/vector")
                file(REAL_PATH "${tb_dir}/vector" tb_vector_header)
                break()
            endif()
        endforeach()
        unset(tb_inc_dirs)
        unset(tb_cc_lines)
    endif()
    unset(tb_cc_verbose)
    unset(tb_cc_result)
    if(NOT tb_vector_header)
        find_file(
            tb_vector_header vector
            PATHS ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}
            NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH NO_CACHE)
    endif()
    if(NOT tb_vector_header)
        set(tb_vector_header "n/a")
    endif()

    file(MAKE_DIRECTORY "${arg_OUT_DIR}")
    set(tb_out_cpp "${arg_OUT_DIR}/${arg_TARGET}.cpp")
    configure_file("${arg_TEMPLATE}" "${tb_out_cpp}" @ONLY)

    # Generated file is not hand-written: skip clang-tidy/cpplint for it.
    # Hand-written sources (main.cpp, build_info.hpp) are still linted.
    set_source_files_properties("${tb_out_cpp}" PROPERTIES SKIP_LINTING ON)

    target_sources(${arg_TARGET} PRIVATE "${tb_out_cpp}")
    target_compile_features(${arg_TARGET} PRIVATE cxx_std_20)
endfunction()
