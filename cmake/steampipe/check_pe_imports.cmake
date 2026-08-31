# --- Windows PE import gate (Steam static-CRT check) -----------------
# Lists every DLL each PE binary imports and fails when an import is on
# the forbidden list. Steam depots must not rely on the VC++
# redistributable or MinGW runtime DLLs being present on the user's
# machine — link the C/C++ runtime statically instead.
#
# One cross-platform script instead of a sh/ps1 pair. Inspectors,
# auto-detected (both print a parseable import table):
#   dumpbin /dependents  — MSVC developer environment
#   llvm-objdump -p      — force with -DOBJDUMP=<path> (e.g. llvm-mingw)
#   objdump -p           — GNU binutils
#
# Usage:
#   cmake -DTARGETS="file-or-dir;..." [-DOBJDUMP=path]
#         [-DFORBIDDEN="a.dll;..."] -P check_pe_imports.cmake
# Exit: 0 = clean; non-zero = forbidden import, inspection failure, or
# usage error.
#
# Note: CMake regexes have no \t/\r escapes (a literal 't'/'r' is matched
# instead) — normalize whitespace with string(STRIP) before matching.
# ---------------------------------------------------------------------

if(NOT DEFINED TARGETS OR TARGETS STREQUAL "")
    message(
        FATAL_ERROR
        "TARGETS is required (semicolon list of PE files or directories)")
endif()

# Default denylist: VC++ redistributable + MinGW/LLVM C/C++ runtime DLLs.
if(NOT DEFINED FORBIDDEN OR FORBIDDEN STREQUAL "")
    set(FORBIDDEN
        vcruntime140.dll
        vcruntime140_1.dll
        msvcp140.dll
        msvcp140_1.dll
        msvcp140_2.dll
        concrt140.dll
        vccorlib140.dll
        libstdc++-6.dll
        libgcc_s_seh-1.dll
        libgcc_s_sjlj-1.dll
        libwinpthread-1.dll
        libc++.dll
        libunwind.dll)
endif()

set(forbidden_lc)
foreach(dll IN LISTS FORBIDDEN)
    string(TOLOWER "${dll}" dll_lc)
    list(APPEND forbidden_lc "${dll_lc}")
endforeach()

# --- Pick the inspector ------------------------------------------------
if(DEFINED OBJDUMP AND NOT OBJDUMP STREQUAL "")
    if(NOT EXISTS "${OBJDUMP}")
        message(FATAL_ERROR "OBJDUMP does not exist: ${OBJDUMP}")
    endif()
    set(inspector "${OBJDUMP}")
    set(inspector_args -p)
else()
    find_program(dumpbin_exe NAMES dumpbin)
    if(dumpbin_exe)
        set(inspector "${dumpbin_exe}")
        set(inspector_args /nologo /dependents)
    else()
        find_program(objdump_exe NAMES llvm-objdump objdump)
        if(NOT objdump_exe)
            message(
                FATAL_ERROR
                "no PE inspector found — pass -DOBJDUMP= or install dumpbin (MSVC) / objdump")
        endif()
        set(inspector "${objdump_exe}")
        set(inspector_args -p)
    endif()
endif()

# --- Collect PE binaries (MZ magic) ------------------------------------
set(pe_files)
foreach(target IN LISTS TARGETS)
    if(IS_DIRECTORY "${target}")
        file(GLOB_RECURSE found LIST_DIRECTORIES FALSE
             "${target}/*.exe" "${target}/*.dll")
        list(APPEND pe_files ${found})
    elseif(EXISTS "${target}")
        list(APPEND pe_files "${target}")
    else()
        message(FATAL_ERROR "no such file or directory: ${target}")
    endif()
endforeach()

set(binaries)
foreach(pe IN LISTS pe_files)
    if(NOT EXISTS "${pe}") # broken symlink — file(READ) would be fatal
        continue()
    endif()
    file(READ "${pe}" magic OFFSET 0 LIMIT 2 HEX)
    if(magic STREQUAL "4d5a")
        list(APPEND binaries "${pe}")
    endif()
endforeach()

list(LENGTH binaries binary_count)
if(binary_count EQUAL 0)
    message(FATAL_ERROR "no PE binaries found under: ${TARGETS}")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/gate_log.cmake")
set(failures 0)

foreach(pe IN LISTS binaries)
    gate_echo("-- ${pe}")
    # Fail closed: a failed inspection must not parse as an empty import
    # list — that would misreport the binary as fully static.
    execute_process(
        COMMAND "${inspector}" ${inspector_args} "${pe}"
        RESULT_VARIABLE inspect_rv
        OUTPUT_VARIABLE inspect_out
        ERROR_VARIABLE inspect_err)
    if(NOT inspect_rv EQUAL 0)
        gate_error("file=${pe}::${inspector} failed to inspect this file")
        continue()
    endif()

    # One pass, both formats: objdump prints "DLL Name: X.dll", dumpbin
    # prints the bare indented name under "the following dependencies:".
    set(imports)
    string(REPLACE "\n" ";" lines "${inspect_out}")
    foreach(line IN LISTS lines)
        string(STRIP "${line}" line)
        if(line MATCHES [==[DLL Name:[ ]+([^ ]+)$]==])
            list(APPEND imports "${CMAKE_MATCH_1}")
        elseif(line MATCHES [==[^([A-Za-z0-9_.+-]+\.[Dd][Ll][Ll])$]==])
            list(APPEND imports "${CMAKE_MATCH_1}")
        endif()
    endforeach()
    list(LENGTH imports import_count)
    if(import_count EQUAL 0)
        gate_echo("   no DLL imports — fully static, OK")
        continue()
    endif()
    list(REMOVE_DUPLICATES imports)
    list(SORT imports CASE INSENSITIVE)

    foreach(dll IN LISTS imports)
        gate_echo("   ${dll}")
        string(TOLOWER "${dll}" dll_lc)
        if(dll_lc IN_LIST forbidden_lc)
            gate_error(
                "file=${pe}::forbidden import '${dll}' — link the C/C++ runtime statically for Steam")
        endif()
    endforeach()
endforeach()

gate_echo("----------------------------------------------------------------------")
if(failures GREATER 0)
    message(FATAL_ERROR "PE import gate FAILED — ${failures} violation(s)")
endif()
message(STATUS "PE import gate passed — ${binary_count} binaries clean")
