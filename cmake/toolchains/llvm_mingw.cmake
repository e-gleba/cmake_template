cmake_minimum_required(VERSION 3.31)

if(NOT CMAKE_SYSTEM_PROCESSOR)
    set(CMAKE_SYSTEM_PROCESSOR "x86_64")
endif()

if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
    set(lm_triple "x86_64-w64-mingw32")
elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "i686")
    set(lm_triple "i686-w64-mingw32")
elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
    set(lm_triple "aarch64-w64-mingw32")
elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "armv7")
    set(lm_triple "armv7-w64-mingw32")
else()
    message(FATAL_ERROR "Unsupported target: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

if(NOT DEFINED DOWNLOAD_LLVM_MINGW_IF_NOT_EXIST)
    set(DOWNLOAD_LLVM_MINGW_IF_NOT_EXIST ON)
endif()

set(lm_ver "20260224")
set(lm_root "${CMAKE_SOURCE_DIR}/llvm_mingw")

if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
    set(lm_host_arch "aarch64")
else()
    set(lm_host_arch "x86_64")
endif()

set(lm_pkg "llvm-mingw-${lm_ver}-ucrt-ubuntu-22.04-${lm_host_arch}")

message(CHECK_START "llvm-mingw")

if(NOT EXISTS "${lm_root}/bin/clang")
    if(NOT DOWNLOAD_LLVM_MINGW_IF_NOT_EXIST)
        message(
            FATAL_ERROR "llvm-mingw not found at '${lm_root}'"
                        " => re-run with -DDOWNLOAD_LLVM_MINGW_IF_NOT_EXIST=ON")
    endif()

    set(lm_archive "${CMAKE_SOURCE_DIR}/${lm_pkg}.tar.xz")

    message(
        STATUS
            "fetching llvm-mingw ${lm_ver} [host=${lm_host_arch} target=${lm_triple}]..."
        )

    file(
        DOWNLOAD
        "https://github.com/mstorsjo/llvm-mingw/releases/download/${lm_ver}/${lm_pkg}.tar.xz"
        "${lm_archive}"
        SHOW_PROGRESS)

    execute_process(
        COMMAND ${CMAKE_COMMAND} -E tar xf "${lm_archive}"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}" COMMAND_ERROR_IS_FATAL ANY)

    file(REMOVE_RECURSE "${lm_root}")
    file(RENAME "${CMAKE_SOURCE_DIR}/${lm_pkg}" "${lm_root}")
    file(REMOVE "${lm_archive}")
endif()

message(CHECK_PASS "'${lm_root}'")

# --- Sysroot & search paths ---
set(CMAKE_SYSROOT "${lm_root}/${lm_triple}")
set(CMAKE_FIND_ROOT_PATH "${lm_root}" "${lm_root}/${lm_triple}")

# --- Compilers (use full paths so CMake doesn't search) ---
set(CMAKE_C_COMPILER "${lm_root}/bin/${lm_triple}-clang")
set(CMAKE_CXX_COMPILER "${lm_root}/bin/${lm_triple}-clang++")
set(CMAKE_RC_COMPILER "${lm_root}/bin/${lm_triple}-windres")
set(CMAKE_AR "${lm_root}/bin/llvm-ar")
set(CMAKE_RANLIB "${lm_root}/bin/llvm-ranlib")
set(CMAKE_STRIP "${lm_root}/bin/llvm-strip")
set(CMAKE_OBJCOPY "${lm_root}/bin/llvm-objcopy")
set(CMAKE_OBJDUMP "${lm_root}/bin/llvm-objdump")
set(CMAKE_NM "${lm_root}/bin/llvm-nm")
set(CMAKE_DLLTOOL "${lm_root}/bin/llvm-dlltool")
set(CMAKE_ADDR2LINE "${lm_root}/bin/llvm-addr2line")
set(CMAKE_SIZE "${lm_root}/bin/llvm-size")
set(CMAKE_READELF "${lm_root}/bin/llvm-readelf")
set(CMAKE_MT "${lm_root}/bin/llvm-mt")

# --- Target triple (triple-prefixed binaries already encode this) ---
set(CMAKE_C_COMPILER_TARGET "${lm_triple}")
set(CMAKE_CXX_COMPILER_TARGET "${lm_triple}")
set(CMAKE_RC_COMPILER_TARGET "${lm_triple}")

# --- Linker ---
set(CMAKE_LINKER_TYPE LLD)
set(CMAKE_EXE_LINKER_FLAGS "-static-libgcc -static-libstdc++ -fuse-ld=lld"
    CACHE INTERNAL "")
set(CMAKE_SHARED_LINKER_FLAGS "-static-libgcc -static-libstdc++ -fuse-ld=lld"
    CACHE INTERNAL "")
set(CMAKE_MODULE_LINKER_FLAGS "-static-libgcc -static-libstdc++ -fuse-ld=lld"
    CACHE INTERNAL "")

set(CMAKE_C_FLAGS "--target=${lm_triple}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS "--target=${lm_triple}" CACHE INTERNAL "")
set(CMAKE_RC_FLAGS "--target=${lm_triple}" CACHE INTERNAL "")

set(CMAKE_CONFIGURE_DEPENDS_PARALLEL ON)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
