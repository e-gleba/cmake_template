if(NOT DEFINED PROJECT_FILE OR PROJECT_FILE STREQUAL "")
    message(FATAL_ERROR "PROJECT_FILE is required")
endif()

if(NOT DEFINED VERSION OR NOT VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
    message(FATAL_ERROR "VERSION must be a three-component numeric version")
endif()

file(READ "${PROJECT_FILE}" content)
string(
    REGEX MATCHALL
    "VERSION[ \t\r\n]+[0-9]+\\.[0-9]+\\.[0-9]+"
    version_declarations
    "${content}")
list(LENGTH version_declarations declaration_count)

if(NOT declaration_count EQUAL 1)
    message(FATAL_ERROR "expected exactly one project VERSION declaration in ${PROJECT_FILE}")
endif()

string(
    REGEX REPLACE
    "VERSION([ \t\r\n]+)[0-9]+\\.[0-9]+\\.[0-9]+"
    "VERSION\\1${VERSION}"
    updated_content
    "${content}")
file(WRITE "${PROJECT_FILE}" "${updated_content}")
