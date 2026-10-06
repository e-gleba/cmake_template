# Demo sessions: record with asciinema, render GIFs with agg.
#
# Usage (from repo root):
#   cmake -P assets/casts/record.cmake
#
# Run a single session (used internally as the recorded command):
#   cmake -Dct_session=quickstart -P assets/casts/record.cmake
#
# Replay without re-recording:
#   asciinema play assets/casts/quickstart.cast
#
# Needs asciinema + agg on PATH (cargo installs live in ~/.cargo/bin).
# Edit CONFIG and re-run to recreate everything.
cmake_minimum_required(VERSION 3.20)

# --- CONFIG ---
set(CT_RECORD_THEME "dracula")
set(CT_RECORD_FONT_SIZE "16")
set(CT_RECORD_IDLE "2")
set(CT_RECORD_FPS "15")
set(CT_RECORD_SESSIONS quickstart package)
# --- END CONFIG ---

get_filename_component(ct_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(ct_casts "${ct_root}/assets/casts")

if(WIN32)
    set(ct_cargo_bin "$ENV{USERPROFILE}/.cargo/bin")
else()
    set(ct_cargo_bin "$ENV{HOME}/.cargo/bin")
endif()
find_program(
    ct_asciinema
    NAMES asciinema
    HINTS "${ct_cargo_bin}")
find_program(
    ct_agg
    NAMES agg
    HINTS "${ct_cargo_bin}")
if(NOT ct_asciinema OR NOT ct_agg)
    message(FATAL_ERROR "need asciinema + agg on PATH (cargo: ~/.cargo/bin)")
endif()

# Echo the command to stdout, live output (no capture, so the recording
# shows the real terminal stream), automatic fatal error on failure —
# no manual RESULT_VARIABLE checks.
function(ct_demo)
    execute_process(
        COMMAND ${ARGN}
        WORKING_DIRECTORY
            "${ct_root}"
            COMMAND_ECHO
            STDOUT
            COMMAND_ERROR_IS_FATAL
            ANY)
endfunction()

function(ct_session_quickstart)
    file(REMOVE_RECURSE "${ct_root}/build/linux_gcc_x86_64")
    ct_demo(cmake --preset linux_gcc_x86_64)
    ct_demo(
        cmake
        --build
        --preset
        linux_gcc_x86_64_release)
    ct_demo(ctest --preset linux_gcc_x86_64_release)
endfunction()

function(ct_session_package)
    file(REMOVE_RECURSE "${ct_root}/build/linux_gcc_x86_64")
    ct_demo(
        cmake
        --workflow
        --preset
        linux_gcc_x86_64_release_package)
    file(GLOB tgz "${ct_root}/build/linux_gcc_x86_64/*.tar.gz")
    message("$ ls build/linux_gcc_x86_64/*.tar.gz")
    message("${tgz}")
endfunction()

# Child mode: asciinema runs `cmake -Dct_session=<name> -P record.cmake`.
if(DEFINED ct_session)
    cmake_language(CALL "ct_session_${ct_session}")
    return()
endif()

foreach(s IN LISTS CT_RECORD_SESSIONS)
    execute_process(
        COMMAND
            "${ct_asciinema}" rec --overwrite --idle-time-limit
            "${CT_RECORD_IDLE}" --command
            "cmake -Dct_session=${s} -P ${ct_casts}/record.cmake"
            "${ct_casts}/${s}.cast" COMMAND_ERROR_IS_FATAL ANY)
    execute_process(
        COMMAND
            "${ct_agg}" --theme "${CT_RECORD_THEME}" --font-size
            "${CT_RECORD_FONT_SIZE}" --idle-time-limit "${CT_RECORD_IDLE}"
            --fps-cap "${CT_RECORD_FPS}" "${ct_casts}/${s}.cast"
            "${ct_casts}/${s}.gif" COMMAND_ERROR_IS_FATAL ANY)
endforeach()
