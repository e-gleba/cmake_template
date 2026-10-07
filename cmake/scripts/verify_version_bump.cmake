# Proves set_project_version.cmake rewrote exactly the project VERSION:
# the project version must equal EXPECTED and no file besides PROJECT_FILE
# may differ.
#
#   cmake -DPROJECT_FILE=CMakeLists.txt -DEXPECTED=1.2.4
#       -P cmake/scripts/verify_version_bump.cmake
#
# Same declaration regex as get_project_version.cmake — keep in sync.

if(NOT DEFINED PROJECT_FILE OR PROJECT_FILE STREQUAL "")
    message(FATAL_ERROR "PROJECT_FILE is required")
endif()

if(NOT DEFINED EXPECTED OR EXPECTED STREQUAL "")
    message(FATAL_ERROR "EXPECTED is required (the bumped version)")
endif()

file(READ "${PROJECT_FILE}" content)

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

string(
    REGEX MATCH
    [==[VERSION[ \t\r\n]+([0-9]+\.[0-9]+\.[0-9]+)]==]
    version_declaration
    "${content}")

if(NOT CMAKE_MATCH_1 STREQUAL EXPECTED)
    message(
        FATAL_ERROR
        "expected CMake project version ${EXPECTED}, got ${CMAKE_MATCH_1}")
endif()

find_package(Git REQUIRED)

execute_process(
    COMMAND "${GIT_EXECUTABLE}" diff --check
    RESULT_VARIABLE check_rv)
if(NOT check_rv EQUAL 0)
    message(FATAL_ERROR "git diff --check found whitespace errors")
endif()

execute_process(
    COMMAND "${GIT_EXECUTABLE}" diff --exit-code -- . ":!${PROJECT_FILE}"
    RESULT_VARIABLE diff_rv)
if(NOT diff_rv EQUAL 0)
    message(
        FATAL_ERROR
        "files other than ${PROJECT_FILE} changed during the version bump")
endif()

message(STATUS "version bump verified: ${PROJECT_FILE} at ${EXPECTED}")
