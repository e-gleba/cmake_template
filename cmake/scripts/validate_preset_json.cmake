# Validates every CMake preset file parses as JSON and carries the
# mandatory version field. The schema/include check itself stays
# cmake --list-presets=all; this replaces find | xargs jq.
#
#   cmake -P cmake/scripts/validate_preset_json.cmake
#
# Paths anchor at this script, so it runs from any working directory.

cmake_path(GET CMAKE_CURRENT_LIST_DIR PARENT_PATH cmake_dir)
cmake_path(GET cmake_dir PARENT_PATH root_dir)

file(
    GLOB preset_files
    LIST_DIRECTORIES FALSE
    "${cmake_dir}/presets/*.json")
list(APPEND preset_files "${root_dir}/CMakePresets.json")
list(REMOVE_DUPLICATES preset_files)
list(SORT preset_files)

foreach(preset_file IN LISTS preset_files)
    file(READ "${preset_file}" content)
    # Success reports the literal NOTFOUND; anything else is the parse error.
    string(JSON preset_version ERROR_VARIABLE json_error GET "${content}" version)
    if(NOT json_error STREQUAL "NOTFOUND")
        message(FATAL_ERROR "invalid preset JSON in ${preset_file}: ${json_error}")
    endif()
    message(STATUS "${preset_file} (version ${preset_version})")
endforeach()

message(STATUS "all preset files are valid JSON")
