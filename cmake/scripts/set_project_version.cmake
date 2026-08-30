# Rewrites the project() VERSION declaration in project_file to version,
# then reads the file back and fails if the bump did not take effect.
# Usage: cmake -Dproject_file=CMakeLists.txt -Dversion=1.2.4 -P cmake/scripts/set_project_version.cmake

if(NOT DEFINED project_file OR project_file STREQUAL "")
    message(FATAL_ERROR "project_file is required")
endif()

if(NOT DEFINED version OR NOT version MATCHES "^[0-9]+\.[0-9]+\.[0-9]+$")
    message(FATAL_ERROR "version must be a three-component numeric version")
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
    previous_version
    "${version_declarations}")

string(
    REGEX REPLACE
    "VERSION([ \t\r\n]+)[0-9]+\.[0-9]+\.[0-9]+"
    "VERSION\1${version}"
    updated_content
    "${content}")
file(WRITE "${project_file}" "${updated_content}")

# Read back: a silent regex no-op must fail the release, not pass it.
file(READ "${project_file}" verified_content)
string(
    REGEX MATCH
    "VERSION[ \t\r\n]+[0-9]+\.[0-9]+\.[0-9]+"
    verified_declaration
    "${verified_content}")
string(
    REGEX MATCH
    "[0-9]+\.[0-9]+\.[0-9]+"
    verified_version
    "${verified_declaration}")
if(NOT verified_version STREQUAL version)
    message(
        FATAL_ERROR
        "version bump did not take effect in ${project_file} (found '${verified_version}')")
endif()

message(STATUS "project version: ${previous_version} -> ${version}")
