cpmaddpackage(
    NAME
    doctest
    GITHUB_REPOSITORY
    doctest/doctest
    VERSION
    2.5.3
    GIT_TAG
    v2.5.2
    GIT_SHALLOW
    ON
    EXCLUDE_FROM_ALL
    ON
    SYSTEM
    ON
    OPTIONS
    "DOCTEST_WITH_TESTS OFF"
    "DOCTEST_WITH_MAIN_IN_STATIC_LIB OFF"
    "DOCTEST_NO_INSTALL ON"
    "DOCTEST_USE_STD_HEADERS ON")

set(doctest_modroot "${doctest_SOURCE_DIR}/scripts/cmake")

list(APPEND CMAKE_MODULE_PATH "${doctest_modroot}")
message(STATUS "added to 'CMAKE_MODULE_PATH': ${doctest_modroot}")
