# ─── LLVM-MinGW Cross-Compilation Toolchain ───────────────────
# Cross-compiles from Linux → Windows using llvm-mingw.
# Auto-downloads the toolchain via FetchContent if not present.
#
# Supports targets: x86_64, i686, aarch64, armv7
#
# All self-relative paths use CMAKE_CURRENT_LIST_DIR — the ONLY
# variable invariant during try_compile() re-processing.
#
# Ref: https://github.com/mstorsjo/llvm-mingw
#      https://cmake.org/cmake/help/latest/variable/CMAKE_CURRENT_LIST_DIR.html
# ───────────────────────────────────────────────────────────────

set(CMAKE_SYSTEM_NAME "Windows")

if(NOT CMAKE_SYSTEM_PROCESSOR)
    set(CMAKE_SYSTEM_PROCESSOR "x86_64")
endif()

# ─── Arch → triple mapping ────────────────────────────────────
set(lm_supported_triples
    x86_64
    x86_64-w64-mingw32
    i686
    i686-w64-mingw32
    aarch64
    aarch64-w64-mingw32
    armv7
    armv7-w64-mingw32)

list(LENGTH lm_supported_triples lm_triple_count)
math(EXPR lm_last_index "${lm_triple_count} - 1")
set(lm_triple "")
foreach(idx RANGE 0 ${lm_last_index} 2)
    math(EXPR val_idx "${idx} + 1")
    list(
        GET
        lm_supported_triples
        ${idx}
        lm_arch)
    list(
        GET
        lm_supported_triples
        ${val_idx}
        lm_candidate_triple)
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL lm_arch)
        set(lm_triple "${lm_candidate_triple}")
        break()
    endif()
endforeach()

if(NOT lm_triple)
    message(
        FATAL_ERROR
            "Unsupported CMAKE_SYSTEM_PROCESSOR: '${CMAKE_SYSTEM_PROCESSOR}'\n"
            "Supported values: x86_64, i686, aarch64, armv7")
endif()

# ─── Toolchain root ───────────────────────────────────────────
set(lm_root "${CMAKE_CURRENT_LIST_DIR}/llvm_mingw")

# ─── Auto-download llvm-mingw via FetchContent ────────────────
# FetchContent replaces the manual file(DOWNLOAD) +
# file(ARCHIVE_EXTRACT) + file(RENAME) sequence. It handles:
#   - Download with progress reporting
#   - Archive caching (download only happens once)
#   - Extraction with automatic top-level directory stripping
#   - Error handling
#
# CMake 3.30+ (CMP0168 NEW) uses file(DOWNLOAD) +
# file(ARCHIVE_EXTRACT) directly — no ExternalProject sub-build,
# no recursion through this toolchain file.
#
# SOURCE_DIR forces extraction to the same ${lm_root} path the
# rest of the toolchain expects. FetchContent strips the single
# top-level directory from the archive, so bin/clang ends up
# directly in SOURCE_DIR.
#
# The if(NOT EXISTS) guard ensures FetchContent only runs once.
# On subsequent configures and during try_compile re-processing,
# the guard sees the existing clang binary and skips entirely
# (~0ms, no include(FetchContent) overhead).
# ───────────────────────────────────────────────────────────────
if(NOT EXISTS "${lm_root}/bin/clang")
    set(lm_ver "20260224")

    if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
        set(lm_host_arch "aarch64")
    else()
        set(lm_host_arch "x86_64")
    endif()

    set(lm_pkg "llvm-mingw-${lm_ver}-ucrt-ubuntu-22.04-${lm_host_arch}")

    include(FetchContent)

    fetchcontent_declare(
        llvm_mingw
        URL "https://github.com/mstorsjo/llvm-mingw/releases/download/${lm_ver}/${lm_pkg}.tar.xz"
            # Extract directly to lm_root — same path as the manual
            # approach, so the rest of the toolchain is unchanged.
            SOURCE_DIR
            "${lm_root}"
            # llvm-mingw has its own CMakeLists.txt for building the
            # toolchain from source. We only want the pre-built binaries.
            # A nonexistent SOURCE_SUBDIR prevents add_subdirectory().
            # Ref: https://cmake.org/cmake/help/latest/module/FetchContent.html
            SOURCE_SUBDIR
            __do_not_add_as_subdirectory__
            DOWNLOAD_EXTRACT_TIMESTAMP
            TRUE)

    fetchcontent_makeavailable(llvm_mingw)

    # ── Verify extraction succeeded ────────────────────────
    if(NOT EXISTS "${lm_root}/bin/clang")
        message(
            FATAL_ERROR
                "llvm-mingw extraction failed: ${lm_root}/bin/clang not found.\n"
                "Try deleting the following directories and reconfiguring:\n"
                "  ${lm_root}\n"
                "  ${FETCHCONTENT_BASE_DIR}")
    endif()
endif()

# ─── Sysroot & search roots ───────────────────────────────────
set(CMAKE_SYSROOT "${lm_root}/${lm_triple}")
set(CMAKE_FIND_ROOT_PATH "${lm_root}" "${CMAKE_SYSROOT}")

# ─── Compilers ─────────────────────────────────────────────────
set(CMAKE_C_COMPILER "${lm_root}/bin/clang")
set(CMAKE_CXX_COMPILER "${lm_root}/bin/clang++")
set(CMAKE_ASM_COMPILER "${lm_root}/bin/clang")

set(CMAKE_C_COMPILER_TARGET "${lm_triple}")
set(CMAKE_CXX_COMPILER_TARGET "${lm_triple}")
set(CMAKE_ASM_COMPILER_TARGET "${lm_triple}")

set(CMAKE_RC_COMPILER "${lm_root}/bin/${lm_triple}-windres")

# ─── LLVM tools (target-agnostic, no triple needed) ───────────
foreach(
    tool
    AR
    RANLIB
    STRIP
    OBJCOPY
    OBJDUMP
    NM
    DLLTOOL
    ADDR2LINE
    SIZE
    READELF
    MT)
    string(TOLOWER "${tool}" lm_tool_lower)
    set(CMAKE_${tool} "${lm_root}/bin/llvm-${lm_tool_lower}")
endforeach()

set(CMAKE_LINKER_TYPE LLD)

# ─── Search-path isolation ────────────────────────────────────
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ─── C++20 module scanning ────────────────────────────────────
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# ─── Compile-only try_compile probes ──────────────────────────
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# ─── PDB debug info (CodeView format) ─────────────────────────
set(CMAKE_C_FLAGS_DEBUG_INIT "-gcodeview")
set(CMAKE_C_FLAGS_RELWITHDEBINFO_INIT "-gcodeview")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-gcodeview")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO_INIT "-gcodeview")

# ─── Static runtime (ALL configs) ─────────────────────────────
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++")

# ─── PDB generation (debug configs ONLY) ──────────────────────
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-Wl,--pdb=")
set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO_INIT "-Wl,--pdb=")

set(CMAKE_SHARED_LINKER_FLAGS_DEBUG_INIT "-Wl,--pdb=")
set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO_INIT "-Wl,--pdb=")

set(CMAKE_MODULE_LINKER_FLAGS_DEBUG_INIT "-Wl,--pdb=")
set(CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO_INIT "-Wl,--pdb=")
