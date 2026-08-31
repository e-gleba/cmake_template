# Print the VERSION of the project() call in PROJECT_FILE to stdout.
#
#   cmake -DPROJECT_FILE=CMakeLists.txt -P cmake/scripts/get_project_version.cmake
#
# Script mode: no configure, no compiler detection, no network. Shares the
# bracket-argument regex idiom with set_project_version.cmake — backslashes
# reach the regex engine untouched.

if(NOT DEFINED PROJECT_FILE OR PROJECT_FILE STREQUAL "")
    message(FATAL_ERROR "PROJECT_FILE is required")
endif()

file(READ "${PROJECT_FILE}" content)

# The VERSION keyword of the project() call, e.g. "VERSION 1.0.0".
string(
    REGEX MATCHALL
    [==[VERSION[ \t\r\n]+[0-9]+\.[0-9]+\.[0-9]+]==]
    version_declarations
    "${content}")
list(LENGTH version_declarations declaration_count)

if(NOT declaration_count EQUAL 1)
    message(
        FATAL_ERROR
        "expected exactly one project VERSION declaration in "
        "${PROJECT_FILE}, found ${declaration_count}")
endif()

# Exactly one declaration: capture its version number. STATUS prints
# "-- <version>" on stdout; callers strip the "-- " prefix.
string(
    REGEX MATCH
    [==[VERSION[ \t\r\n]+([0-9]+\.[0-9]+\.[0-9]+)]==]
    version_declaration
    "${content}")
message(STATUS "${CMAKE_MATCH_1}")
