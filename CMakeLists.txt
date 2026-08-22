cmake_minimum_required(VERSION 4.4)

project(
    cxx_project
    VERSION 1.0.0
    DESCRIPTION "My awesome C/C++ project!"
    HOMEPAGE_URL "https://github.com/e-gleba/cxx-skeleton"
    LANGUAGES C CXX)

# No C++20 modules in use — do not pay for the module dependency scan.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Project modules, loaded by name via include(). CMAKE_CURRENT_LIST_DIR
# (not CMAKE_SOURCE_DIR) keeps this correct when the project is consumed
# via add_subdirectory()/FetchContent.
# Ref: Professional CMake §8.3 "Project-relative Variables"
list(
    APPEND
    CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_LIST_DIR}/cmake"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/description"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/code_quality")

include(cpm) # dependency bootstrap: CPM + package configs
include(warnings) # warnings interface target

if(PROJECT_IS_TOP_LEVEL)
    include(clang_format)
    include(clang_tidy)
    include(clang_doc)
    include(cpplint)
    include(ct_doxygen)
endif()

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

    include(GNUInstallDirs)
    include(package_description)

    # Append processor to system name so packages for different
    # architectures don't collide ("Windows-x86_64" vs "Windows-aarch64").
    string(APPEND CPACK_SYSTEM_NAME "-${CMAKE_SYSTEM_PROCESSOR}")

    # include(CPack) reads all CPACK_* variables at include-time and
    # ignores later changes — keep it last.
    # Ref: Professional CMake §36.1 "Packaging Basics"
    include(CPack)
endif()
