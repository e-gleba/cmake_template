cmake_minimum_required(VERSION 4.4)

project(
    cxx_project
    VERSION 1.0.0
    DESCRIPTION "Production-ready cross-platform C++ project template"
    HOMEPAGE_URL "https://github.com/e-gleba/cmake_template"
    LANGUAGES C CXX)

# No C++20 modules in use — do not pay for the module dependency scan.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Project-owned CMake names use CT_* for user-facing cache variables and
# options, and ct_* for targets, functions, properties, and local variables.
# Built-in and dependency-owned names keep their upstream spelling.

# Project modules, loaded by name via include(). CMAKE_CURRENT_LIST_DIR
# (not CMAKE_SOURCE_DIR) keeps this correct when the project is consumed
# via add_subdirectory()/FetchContent.
# Ref: Professional CMake §8.3 "Project-relative Variables"
list(
    APPEND
    CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_LIST_DIR}/cmake"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/cpack"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/code_quality")

include(ct_cpm) # dependency bootstrap: CPM + package configs
include(ct_warnings) # warnings interface target

if(PROJECT_IS_TOP_LEVEL)
    include(ct_clang_format)
    include(ct_clang_tidy)
    include(ct_clang_doc)
    include(ct_cpplint)
    include(ct_doxygen)
endif()

include(GNUInstallDirs)
add_subdirectory(src)

# Testing and packaging only run when this project owns the build. A parent
# project pulling us in via add_subdirectory()/FetchContent controls both
# itself — we must not interfere.
# Ref: Professional CMake §8.3, §39 "FetchContent"
if(PROJECT_IS_TOP_LEVEL)
    # include(CTest) creates the BUILD_TESTING cache option (default ON).
    include(CTest)

    if(BUILD_TESTING)
        add_subdirectory(tests)
    endif()

    include(ct_cpack)

    # include(CPack) reads all CPACK_* variables at include-time and
    # ignores later changes — keep it last.
    # Ref: Professional CMake §36.1 "Packaging Basics"
    include(CPack)
endif()
