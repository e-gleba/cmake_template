# --- cpplint: Google C++ style checker ----------------------------------------
# Two integration modes:
#   1. Co-compilation  - CMAKE_<LANG>_CPPLINT (Makefiles/Ninja only)
#   2. Standalone      - '${PROJECT_NAME}-cpplint' target (any generator)

find_program(
    cpplint_exe
    NAMES cpplint
    DOC "cpplint: google C++ style checker" OPTIONAL)

if(NOT cpplint_exe)
    message(
        NOTICE
        "cpplint not found - cpplint linting disabled\n"
        "  pip:     pip install cpplint\n"
        "  fedora:  sudo dnf install cpplint\n"
        "  macos:   brew install cpplint")
    return()
endif()

# --- co-compilation (per-file, during build) ----------------------------------
# CMAKE_<LANG>_CPPLINT integrates cpplint into the compile step.
# Only fires for Makefile/Ninja generators; silently ignored elsewhere.
# Ref: Professional CMake 32.3, cmake.org <LANG>_CPPLINT property.
# The project enables both C and CXX - lint both.
foreach(lang IN ITEMS C CXX)
    set(CMAKE_${lang}_CPPLINT
        "${cpplint_exe}"
        CACHE STRING "cpplint command line for co-compilation linting")
endforeach()

# --- standalone target (whole-tree sweep) -------------------------------------
# cpplint walks directories itself with --recursive: no file list to
# maintain, no ARG_MAX ceiling, and new files are picked up on every
# run - no globbing needed at all.
set(cpplint_scan_dirs "")
foreach(dir IN ITEMS src include tests)
    if(IS_DIRECTORY "${PROJECT_SOURCE_DIR}/${dir}")
        list(APPEND cpplint_scan_dirs "${PROJECT_SOURCE_DIR}/${dir}")
    endif()
endforeach()

if(cpplint_scan_dirs)
    add_custom_target(
        ${PROJECT_NAME}-cpplint
        COMMAND "${cpplint_exe}" --recursive --quiet ${cpplint_scan_dirs}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        VERBATIM
        COMMENT "running cpplint on ${PROJECT_NAME} sources"
        USES_TERMINAL)
endif()
