# Rewrite the VERSION field of the project() call in PROJECT_FILE.
#
#   cmake -DPROJECT_FILE=CMakeLists.txt -DVERSION=1.2.3 \
#       -P cmake/scripts/set_project_version.cmake
#
# Every regex is a bracket argument ([==[ ]==]): backslashes reach the
# regex engine untouched, so there is no quoted-string escaping to get
# wrong. The previous version used "\\\\." which the regex engine saw as
# a literal backslash followed by any character — matching nothing.

if(NOT DEFINED PROJECT_FILE OR PROJECT_FILE STREQUAL "")
    message(FATAL_ERROR "PROJECT_FILE is required")
endif()

# Plain major.minor.patch, e.g. 1.2.3.
set(version_pattern [==[[0-9]+\.[0-9]+\.[0-9]+]==])

if(NOT DEFINED VERSION OR NOT VERSION MATCHES "^${version_pattern}$")
    message(
        FATAL_ERROR
        "VERSION must be a three-component numeric version, got '${VERSION}'")
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

# Group 1 captures the whitespace after VERSION so only the number is
# rewritten. Replacement backreferences are single-digit (\1..\9), so
# "\1" directly followed by the new version number is unambiguous.
string(
    REGEX REPLACE
    [==[VERSION([ \t\r\n]+)[0-9]+\.[0-9]+\.[0-9]+]==]
    "VERSION\\1${VERSION}"
    updated_content
    "${content}")

file(WRITE "${PROJECT_FILE}" "${updated_content}")

message(STATUS "set ${PROJECT_FILE} project VERSION to ${VERSION}")
