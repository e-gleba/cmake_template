cmake_minimum_required(VERSION 3.31)

# --- User-configurable option (default: ON) ---
if(NOT DEFINED DOWNLOAD_LLVM_MINGW_IF_NOT_EXIST)
    set(DOWNLOAD_LLVM_MINGW_IF_NOT_EXIST ON)
endif()

# --- Constants ---
set(lm_ver "20260224")
set(lm_os "ubuntu-22.04")

if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
    set(lm_host_arch "aarch64")
else()
    set(lm_host_arch "x86_64")
endif()

set(lm_prefix "${CMAKE_SYSTEM_PROCESSOR}-w64-mingw32")
set(lm_pkg "llvm-mingw-${lm_ver}-ucrt-${lm_os}-${lm_host_arch}")
set(lm_root "${CMAKE_SOURCE_DIR}/llvm_mingw")

# --- Download if needed ---
message(CHECK_START "llvm-mingw")

if(NOT EXISTS "${lm_root}/bin/clang")
    if(NOT DOWNLOAD_LLVM_MINGW_IF_NOT_EXIST)
        message(
            FATAL_ERROR "llvm-mingw not found at '${lm_root}'"
                        " => re-run with -DDOWNLOAD_LLVM_MINGW_IF_NOT_EXIST=ON")
    endif()

    set(lm_archive "${CMAKE_SOURCE_DIR}/${lm_pkg}.tar.xz")
    set(lm_url
        "https://github.com/mstorsjo/llvm-mingw/releases/download/${lm_ver}/${lm_pkg}.tar.xz"
        )

    message(
        STATUS
            "fetching llvm-mingw ${lm_ver} [host=${lm_host_arch} target=${CMAKE_SYSTEM_PROCESSOR}]..."
        )

    file(DOWNLOAD "${lm_url}" "${lm_archive}" SHOW_PROGRESS STATUS dl_status)
    list(
        GET
        dl_status
        0
        dl_code)
    list(
        GET
        dl_status
        1
        dl_msg)

    if(NOT
       dl_code
       EQUAL
       0)
        file(REMOVE "${lm_archive}")
        message(FATAL_ERROR "download failed: '${dl_msg}'")
    endif()

    message(STATUS "extracting '${lm_pkg}.tar.xz'")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E tar xf "${lm_archive}"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}" COMMAND_ERROR_IS_FATAL ANY)

    file(REMOVE_RECURSE "${lm_root}")
    file(RENAME "${CMAKE_SOURCE_DIR}/${lm_pkg}" "${lm_root}")
    file(REMOVE "${lm_archive}")
endif()

message(CHECK_PASS "'${lm_root}'")

set(CMAKE_C_COMPILER "${lm_root}/bin/${lm_prefix}-clang")
set(CMAKE_CXX_COMPILER "${lm_root}/bin/${lm_prefix}-clang++")
set(CMAKE_RC_COMPILER "${lm_root}/bin/${lm_prefix}-windres")
set(CMAKE_AR "${lm_root}/bin/llvm-ar")
set(CMAKE_RANLIB "${lm_root}/bin/llvm-ranlib")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
