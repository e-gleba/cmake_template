if(NOT DEFINED BUILD_DIR OR BUILD_DIR STREQUAL "")
    message(FATAL_ERROR "BUILD_DIR is required")
endif()

if(NOT DEFINED STAGING_DIR OR STAGING_DIR STREQUAL "")
    message(FATAL_ERROR "STAGING_DIR is required")
endif()

if(NOT IS_DIRECTORY "${BUILD_DIR}")
    message(FATAL_ERROR "build directory does not exist: ${BUILD_DIR}")
endif()

file(GLOB package_candidates LIST_DIRECTORIES FALSE "${BUILD_DIR}/*")
set(package_files)
foreach(candidate IN LISTS package_candidates)
    if(candidate MATCHES "\\.(zip|tar\\.gz|tar\\.xz|apk)$")
        list(APPEND package_files "${candidate}")
    endif()
endforeach()

list(LENGTH package_files package_count)
if(package_count EQUAL 0)
    message(FATAL_ERROR "no release package found in ${BUILD_DIR}")
endif()

file(REMOVE_RECURSE "${STAGING_DIR}")
file(MAKE_DIRECTORY "${STAGING_DIR}")

foreach(package_file IN LISTS package_files)
    get_filename_component(package_name "${package_file}" NAME)
    configure_file(
        "${package_file}"
        "${STAGING_DIR}/${package_name}"
        COPYONLY)
endforeach()

message(STATUS "staged ${package_count} release asset(s) from ${BUILD_DIR}")
