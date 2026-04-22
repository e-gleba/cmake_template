cpmaddpackage(
    NAME
    doctest
    GITHUB_REPOSITORY
    doctest/doctest
    VERSION
    2.5.2
    SYSTEM
    ON
    GIT_SHALLOW
    ON
    EXCLUDE_FROM_ALL
    ON
    OPTIONS
    "DOCTEST_WITH_TESTS OFF"
    "DOCTEST_WITH_MAIN_IN_STATIC_LIB OFF"
    "DOCTEST_NO_INSTALL ON"
    "DOCTEST_USE_STD_HEADERS ON")

if(doctest_ADDED)
    set(doctest_cmake_path "${doctest_SOURCE_DIR}/scripts/cmake")
    set(doctest_source "downloaded")
else()
    set(doctest_cmake_path "${doctest_DIR}")
    set(doctest_source "system")
endif()

list(APPEND CMAKE_MODULE_PATH "${doctest_cmake_path}")
message(STATUS "doctest (${doctest_source}) -> '${doctest_cmake_path}'")
