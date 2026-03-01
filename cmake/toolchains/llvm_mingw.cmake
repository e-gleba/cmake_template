cmake_minimum_required(VERSION 3.31)

set(CMAKE_SYSTEM_NAME "Windows")

if(NOT CMAKE_SYSTEM_PROCESSOR)
    set(CMAKE_SYSTEM_PROCESSOR "x86_64")
endif()

# ─── Arch → triple mapping ────────────────────────────────────────
# Flat paired list: <arch> <mingw-triple>
set(supported_triples
    x86_64
    x86_64-w64-mingw32
    i686
    i686-w64-mingw32
    aarch64
    aarch64-w64-mingw32
    armv7
    armv7-w64-mingw32)

list(LENGTH supported_triples triple_count)
math(EXPR last_index "${triple_count} - 1")
set(lm_triple "")
foreach(idx RANGE 0 ${last_index} 2)
    math(EXPR val_idx "${idx} + 1")
    list(
        GET
        supported_triples
        ${idx}
        arch)
    list(
        GET
        supported_triples
        ${val_idx}
        triple)
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL arch)
        set(lm_triple "${triple}")
        break()
    endif()
endforeach()
if(NOT lm_triple)
    message(FATAL_ERROR "Unsupported target: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(lm_root "${CMAKE_CURRENT_LIST_DIR}/llvm_mingw")

# ─── Auto-download llvm-mingw ─────────────────────────────────────
if(NOT EXISTS "${lm_root}/bin/clang")
    set(lm_ver "20260224")

    if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
        set(lm_host_arch "aarch64")
    else()
        set(lm_host_arch "x86_64")
    endif()

    set(lm_pkg "llvm-mingw-${lm_ver}-ucrt-ubuntu-22.04-${lm_host_arch}")
    set(lm_archive "${CMAKE_CURRENT_BINARY_DIR}/${lm_pkg}.tar.xz")

    # ── Download (skipped when archive already cached) ─────────
    if(NOT EXISTS "${lm_archive}")
        message(
            STATUS
                "Downloading llvm-mingw ${lm_ver} (${lm_host_arch} -> ${lm_triple})..."
        )
        file(
            DOWNLOAD
            "https://github.com/mstorsjo/llvm-mingw/releases/download/${lm_ver}/${lm_pkg}.tar.xz"
            "${lm_archive}"
            SHOW_PROGRESS
            STATUS lm_dl_status)
        list(
            GET
            lm_dl_status
            0
            lm_dl_code)
        if(NOT
           lm_dl_code
           EQUAL
           0)
            list(
                GET
                lm_dl_status
                1
                lm_dl_msg)
            file(REMOVE "${lm_archive}")
            message(FATAL_ERROR "llvm-mingw download failed: ${lm_dl_msg}")
        endif()
    else()
        message(STATUS "Using cached llvm-mingw archive: ${lm_archive}")
    endif()

    # ── Extract ────────────────────────────────────────────────
    message(STATUS "Extracting llvm-mingw ${lm_root}")
    file(
        ARCHIVE_EXTRACT
        INPUT
        "${lm_archive}"
        DESTINATION
        "${CMAKE_CURRENT_BINARY_DIR}")
    file(REMOVE_RECURSE "${lm_root}")
    file(RENAME "${CMAKE_CURRENT_BINARY_DIR}/${lm_pkg}" "${lm_root}")
endif()

# ─── Sysroot & search roots ───────────────────────────────────────
set(CMAKE_SYSROOT "${lm_root}/${lm_triple}")
set(CMAKE_FIND_ROOT_PATH "${lm_root}" "${CMAKE_SYSROOT}")

# ─── Compilers: plain clang/clang++ with --target=<triple> ────────
# Clang is a native cross-compiler. Instead of relying on the
# triple-prefixed wrapper symlinks (x86_64-w64-mingw32-clang),
# we point at the real binaries and let CMAKE_<LANG>_COMPILER_TARGET
# inject --target=<triple> into every compile and link invocation.
# This is functionally identical, but explicit and auditable in logs.
# Ref: https://clang.llvm.org/docs/CrossCompilation.html
set(CMAKE_C_COMPILER "${lm_root}/bin/clang")
set(CMAKE_CXX_COMPILER "${lm_root}/bin/clang++")
set(CMAKE_ASM_COMPILER "${lm_root}/bin/clang")

set(CMAKE_C_COMPILER_TARGET "${lm_triple}")
set(CMAKE_CXX_COMPILER_TARGET "${lm_triple}")
set(CMAKE_ASM_COMPILER_TARGET "${lm_triple}")

# RC compiler — llvm-windres dispatches on argv[0] to determine the
# target architecture. There is no --target= flag for windres, so
# the triple-prefixed wrapper is still required here.
set(CMAKE_RC_COMPILER "${lm_root}/bin/${lm_triple}-windres")

# ─── LLVM tools — already target-agnostic, no triple needed ───────
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
    string(TOLOWER "${tool}" tool_lower)
    set(CMAKE_${tool} "${lm_root}/bin/llvm-${tool_lower}")
endforeach()

set(CMAKE_LINKER_TYPE LLD)

# ─── Search-path isolation ────────────────────────────────────────
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ─── PDB debug info (CodeView) ────────────────────────────────────
# -gcodeview only produces output when -g is active (Debug,
# RelWithDebInfo). Restrict to those configs so Release build
# logs stay clean.
set(CMAKE_C_FLAGS_DEBUG_INIT "-gcodeview")
set(CMAKE_C_FLAGS_RELWITHDEBINFO_INIT "-gcodeview")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-gcodeview")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO_INIT "-gcodeview")

# ─── Static runtime (ALL configs) ─────────────────────────────────
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++")

# ─── PDB generation (debug configs ONLY) ──────────────────────────
# --pdb= tells LLD to emit a .pdb next to the output binary.
# Only useful when -gcodeview is active. In Release, this flag
# forces LLD to walk the entire static-linked symbol table
# (compiler-rt + libc++ + libc++abi + libunwind + your code)
# to produce a nearly empty PDB — which takes minutes for no value.
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-Wl,--pdb=")
set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO_INIT "-Wl,--pdb=")

set(CMAKE_SHARED_LINKER_FLAGS_DEBUG_INIT "-Wl,--pdb=")
set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO_INIT "-Wl,--pdb=")

set(CMAKE_MODULE_LINKER_FLAGS_DEBUG_INIT "-Wl,--pdb=")
set(CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO_INIT "-Wl,--pdb=")
