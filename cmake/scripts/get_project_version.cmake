# Prints the project() VERSION declared in project_file to stdout as
# "PROJECT_VERSION=<major.minor.patch>" for CI to scrape. Script mode only:
# no configure, no network — runs in milliseconds.
# Usage: cmake -Dproject_file=CMakeLists.txt -P cmake/scripts/get_project_version.cmake

if(NOT DEFINED project_file OR project_file STREQUAL "")
    message(FATAL_ERROR "project_file is required")
endif()

file(READ "${project_file}" content)
string(
    REGEX MATCHALL
    "VERSION[ \t\r\n]+[0-9]+\.[0-9]+\.[0-9]+"
    version_declarations
    "${content}")
list(LENGTH version_declarations declaration_count)

if(NOT declaration_count EQUAL 1)
    message(
        FATAL_ERROR
        "expected exactly one project VERSION declaration in ${project_file}")
endif()

string(
    REGEX MATCH
    "[0-9]+\.[0-9]+\.[0-9]+"
    project_version
    "${version_declarations}")

# No STATUS keyword: plain message() writes to stdout without the "-- " prefix.
message("PROJECT_VERSION=${project_version}")
