# --- steamrt platform loader gate --------------------------------------
# Validates that every staged binary LOADS on the Steam Runtime platform
# image — the minimal client-identical runtime that ships to Steam Deck
# and desktop users (and the Proton base). The platform image has no
# shell and no binutils, so the dynamic loader itself is the gate:
# ld-linux --list prints which runtime path every NEEDED library is
# taken from; any "not found" fails. GUI binaries need no display for
# --list — this gate covers them.
#
# Usage:
#   cmake -DROOT=<dir with bin/ and lib/> [-DIMAGE=<platform image>]
#         -P check_steamrt_loader.cmake
# IMAGE defaults to the STEAMRT4_PLATFORM_IMAGE environment variable.
# ----------------------------------------------------------------------

if(NOT DEFINED ROOT OR ROOT STREQUAL "")
    message(FATAL_ERROR "ROOT is required (directory with bin/ and lib/)")
endif()
if(NOT IS_DIRECTORY "${ROOT}/bin")
    message(FATAL_ERROR "no bin/ directory under ROOT: ${ROOT}")
endif()

if(NOT DEFINED IMAGE OR IMAGE STREQUAL "")
    set(IMAGE "$ENV{STEAMRT4_PLATFORM_IMAGE}")
endif()
if(IMAGE STREQUAL "")
    message(
        FATAL_ERROR
        "IMAGE is required (-DIMAGE= or the STEAMRT4_PLATFORM_IMAGE env var)")
endif()

file(GLOB bins LIST_DIRECTORIES FALSE "${ROOT}/bin/*")
list(LENGTH bins bin_count)
if(bin_count EQUAL 0)
    message(FATAL_ERROR "no binaries under ${ROOT}/bin")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/gate_log.cmake")
set(failures 0)

foreach(bin IN LISTS bins)
    get_filename_component(name "${bin}" NAME)
    gate_echo("-- ${name}")
    execute_process(
        COMMAND
            docker run --rm --entrypoint /lib64/ld-linux-x86-64.so.2
            -e LD_LIBRARY_PATH=/opt/app/lib -v "${ROOT}:/opt/app:ro"
            "${IMAGE}" --list "/opt/app/bin/${name}"
        RESULT_VARIABLE rv
        OUTPUT_VARIABLE out
        ERROR_VARIABLE err)
    gate_echo("${out}${err}")
    if(NOT rv EQUAL 0)
        gate_error(
            "file=${name}::loader failed on the steamrt platform runtime (exit ${rv})")
    elseif(out MATCHES "not found" OR err MATCHES "not found")
        gate_error(
            "file=${name}::unresolved libraries on the steamrt platform runtime")
    endif()
endforeach()

gate_echo("----------------------------------------------------------------------")
if(failures GREATER 0)
    message(
        FATAL_ERROR
        "loader gate FAILED — ${failures} of ${bin_count} binaries do not load on the steamrt platform runtime")
endif()
message(
    STATUS
    "loader gate passed — ${bin_count} binaries resolve on the steamrt platform runtime")
