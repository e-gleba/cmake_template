# Validates the release workflow's inputs against project() VERSION.
#
#   cmake -DPROJECT_FILE=CMakeLists.txt
#       [-DVERSION=v1.2.3] [-DNEXT_VERSION=1.2.4]
#       -P cmake/scripts/check_release.cmake
#
# VERSION (tag, e.g. v1.2.3-rc.1): format-checked; its numeric core must
# equal the project version. NEXT_VERSION (plain, e.g. 1.2.4):
# format-checked; must be strictly greater (cmake-native comparison, no
# GNU sort -V, so this also runs on Windows/macOS runners).
#
# Same declaration regex as get_project_version.cmake — keep in sync.
# Bracket arguments carry every regex untouched (no backslash escaping).

if(NOT DEFINED PROJECT_FILE OR PROJECT_FILE STREQUAL "")
    message(FATAL_ERROR "PROJECT_FILE is required")
endif()

if(DEFINED VERSION AND NOT VERSION STREQUAL "")
    if(NOT VERSION MATCHES [==[^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$]==])
        message(
            FATAL_ERROR
            "VERSION must look like v1.2.3 or v1.2.3-rc.1 (got '${VERSION}')")
    endif()
endif()

if(DEFINED NEXT_VERSION AND NOT NEXT_VERSION STREQUAL "")
    if(NOT NEXT_VERSION MATCHES [==[^[0-9]+\.[0-9]+\.[0-9]+$]==])
        message(
            FATAL_ERROR
            "NEXT_VERSION must be plain semver, no v prefix, e.g. 1.2.4 (got '${NEXT_VERSION}')")
    endif()
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
set(current "${CMAKE_MATCH_1}")

if(DEFINED VERSION AND NOT VERSION STREQUAL "")
    string(
        REGEX MATCH
        [==[^v([0-9]+\.[0-9]+\.[0-9]+)]==]
        version_core
        "${VERSION}")
    if(NOT CMAKE_MATCH_1 STREQUAL current)
        message(
            FATAL_ERROR
            "release version core (${CMAKE_MATCH_1}) must match "
            "CMake project version (${current})")
    endif()
endif()

if(DEFINED NEXT_VERSION AND NOT NEXT_VERSION STREQUAL "")
    if(NOT NEXT_VERSION VERSION_GREATER current)
        message(
            FATAL_ERROR
            "NEXT_VERSION (${NEXT_VERSION}) must be greater than "
            "current project version (${current})")
    endif()
endif()

message(STATUS "release inputs satisfy project version ${current}")
