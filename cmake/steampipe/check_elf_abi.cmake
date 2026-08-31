# --- Steam Runtime ABI gate ------------------------------------------
# Verifies ELF binaries against the shared libraries of the runtime they
# currently execute in. Two checks per binary:
#
#   1. Resolution — every NEEDED entry must resolve (ldd shows no
#      "not found"). The resolved paths are printed: evidence of WHERE
#      the loader takes each library from.
#   2. Symbol versions — every versioned symbol the binary REQUIRES
#      (GLIBC_*, GLIBCXX_*, CXXABI_*, GCC_*) must be PROVIDED by the
#      runtime's own libc.so.6 / libstdc++.so.6 / libgcc_s.so.1.
#      Catches "built on a newer distro" breakage before SteamPipe does.
#
# No version is hardcoded — the runtime under test is the baseline.
# Run inside the steamrt4 SDK container (build-time gate) or on any
# machine whose libraries you want to validate against.
#
# Usage: cmake -DTARGETS="elf-file-or-dir;..." -P check_elf_abi.cmake
# Exit:  0 = all compatible; non-zero = violation or usage error
#
# Note: CMake regexes have no \t/\r escapes (a literal 't'/'r' is matched
# instead) — normalize whitespace with string(STRIP) before matching.
# ---------------------------------------------------------------------

if(NOT DEFINED TARGETS OR TARGETS STREQUAL "")
    message(
        FATAL_ERROR
        "TARGETS is required (semicolon list of ELF files or directories)")
endif()

find_program(OBJDUMP_EXE NAMES objdump REQUIRED)
find_program(LDD_EXE NAMES ldd REQUIRED)

# --- Collect ELF binaries ----------------------------------------------
# ELF magic + e_type at offset 16 (little-endian): 2 = executable,
# 3 = shared object/PIE. Relocatable objects (1, e.g. .o in _deps) are
# skipped.
set(candidates)
foreach(target IN LISTS TARGETS)
    if(IS_DIRECTORY "${target}")
        file(GLOB_RECURSE found LIST_DIRECTORIES FALSE "${target}/*")
        list(APPEND candidates ${found})
    elseif(EXISTS "${target}")
        list(APPEND candidates "${target}")
    else()
        message(FATAL_ERROR "no such file or directory: ${target}")
    endif()
endforeach()

set(binaries)
foreach(candidate IN LISTS candidates)
    if(NOT EXISTS "${candidate}") # broken symlink — file(READ) would be fatal
        continue()
    endif()
    file(READ "${candidate}" magic OFFSET 0 LIMIT 4 HEX)
    if(NOT magic STREQUAL "7f454c46")
        continue()
    endif()
    file(READ "${candidate}" elf_type OFFSET 16 LIMIT 1 HEX)
    if(elf_type STREQUAL "02" OR elf_type STREQUAL "03")
        list(APPEND binaries "${candidate}")
    endif()
endforeach()

list(LENGTH binaries binary_count)
if(binary_count EQUAL 0)
    message(FATAL_ERROR "no ELF binaries found under: ${TARGETS}")
endif()

# version-tag family -> soname of the runtime library that must provide it
function(soname_for_prefix prefix out)
    if(prefix STREQUAL "GLIBC")
        set(${out} "libc.so.6" PARENT_SCOPE)
    elseif(prefix STREQUAL "GLIBCXX" OR prefix STREQUAL "CXXABI")
        set(${out} "libstdc++.so.6" PARENT_SCOPE)
    elseif(prefix STREQUAL "GCC")
        set(${out} "libgcc_s.so.1" PARENT_SCOPE)
    else()
        set(${out} "" PARENT_SCOPE)
    endif()
endfunction()

# version tags on the binary's UNDEFINED (imported) dynamic symbols
function(required_versions bin out)
    execute_process(
        COMMAND "${OBJDUMP_EXE}" -T "${bin}"
        RESULT_VARIABLE rv
        OUTPUT_VARIABLE dump
        ERROR_QUIET)
    set(versions)
    if(rv EQUAL 0)
        string(REPLACE "\n" ";" lines "${dump}")
        foreach(line IN LISTS lines)
            if(line MATCHES [==[\*UND\*]==])
                string(REGEX MATCHALL [==[(GLIBCXX|CXXABI|GLIBC|GCC)_[0-9][0-9.]*]==]
                       tags "${line}")
                list(APPEND versions ${tags})
            endif()
        endforeach()
    endif()
    if(versions)
        list(REMOVE_DUPLICATES versions)
    endif()
    set(${out} "${versions}" PARENT_SCOPE)
endfunction()

# all version tags a library defines, minus private nodes
function(provided_versions lib out)
    execute_process(
        COMMAND "${OBJDUMP_EXE}" -T "${lib}"
        RESULT_VARIABLE rv
        OUTPUT_VARIABLE dump
        ERROR_QUIET)
    set(versions)
    if(rv EQUAL 0)
        string(REGEX MATCHALL [==[(GLIBCXX|CXXABI|GLIBC|GCC)_[0-9][0-9.]*]==]
               versions "${dump}")
        list(FILTER versions EXCLUDE REGEX "_PRIVATE")
        if(versions)
            list(REMOVE_DUPLICATES versions)
        endif()
    endif()
    set(${out} "${versions}" PARENT_SCOPE)
endfunction()

include("${CMAKE_CURRENT_LIST_DIR}/gate_log.cmake")
set(failures 0)

foreach(bin IN LISTS binaries)
    gate_echo("-- ${bin}")

    execute_process(
        COMMAND "${OBJDUMP_EXE}" -p "${bin}"
        RESULT_VARIABLE rv
        OUTPUT_VARIABLE private_headers
        ERROR_QUIET)
    if(NOT rv EQUAL 0)
        gate_error("file=${bin}::objdump failed to inspect this file")
        continue()
    endif()
    if(NOT private_headers MATCHES "NEEDED")
        gate_echo("   fully static — no dynamic dependencies, OK")
        continue()
    endif()

    # -- Check 1: resolution map (where the libs are taken from) --------
    execute_process(
        COMMAND "${LDD_EXE}" "${bin}"
        RESULT_VARIABLE ldd_rv
        OUTPUT_VARIABLE ldd_out
        ERROR_VARIABLE ldd_err)
    if(NOT ldd_rv EQUAL 0)
        gate_error("file=${bin}::ldd failed: ${ldd_err}")
        continue()
    endif()
    string(REPLACE "\n" ";" ldd_lines "${ldd_out}")
    foreach(line IN LISTS ldd_lines)
        gate_echo("   ${line}")
    endforeach()
    if(ldd_out MATCHES "not found")
        gate_error(
            "file=${bin}::unresolved NEEDED libraries ('not found' above)")
        continue()
    endif()
    # soname -> resolved path, keyed as variables (CMake has no dicts).
    # The map is per-binary — clear the previous binary's keys first.
    foreach(key IN LISTS resolved_keys)
        unset("resolved_${key}")
    endforeach()
    set(resolved_keys)
    foreach(line IN LISTS ldd_lines)
        string(STRIP "${line}" line) # ldd indents with a tab
        if(line MATCHES [==[^([^ ]+)[ ]+=>[ ]+(/[^ ]+)]==])
            string(MAKE_C_IDENTIFIER "${CMAKE_MATCH_1}" soname_key)
            set(resolved_${soname_key} "${CMAKE_MATCH_2}")
            list(APPEND resolved_keys "${soname_key}")
        endif()
    endforeach()

    # -- Check 2: required symbol versions vs provided ------------------
    required_versions("${bin}" required)
    if(NOT required)
        gate_echo("   no versioned symbol imports, OK")
        continue()
    endif()

    set(binary_failed FALSE)
    foreach(ver IN LISTS required)
        string(REGEX MATCH [==[[A-Z]+]==] prefix "${ver}")
        soname_for_prefix("${prefix}" soname)
        if(soname STREQUAL "")
            continue()
        endif()
        string(MAKE_C_IDENTIFIER "${soname}" soname_key)
        if(NOT DEFINED resolved_${soname_key})
            gate_error(
                "file=${bin}::imports ${ver} but ${soname} is not linked")
            set(binary_failed TRUE)
            continue()
        endif()
        set(libpath "${resolved_${soname_key}}")
        string(MAKE_C_IDENTIFIER "${libpath}" lib_key)
        if(NOT DEFINED provided_${lib_key})
            provided_versions("${libpath}" provided_${lib_key})
        endif()
        if(NOT ver IN_LIST provided_${lib_key})
            gate_error(
                "file=${bin}::imports ${ver} — not provided by ${libpath}")
            set(binary_failed TRUE)
        endif()
    endforeach()

    # summary: highest imported version per family and its provider
    if(NOT binary_failed)
        foreach(prefix IN ITEMS GLIBC GLIBCXX CXXABI GCC)
            set(family)
            foreach(ver IN LISTS required)
                if(ver MATCHES "^${prefix}_")
                    list(APPEND family "${ver}")
                endif()
            endforeach()
            if(family)
                list(SORT family COMPARE NATURAL)
                list(POP_BACK family max_ver)
                soname_for_prefix("${prefix}" soname)
                string(MAKE_C_IDENTIFIER "${soname}" soname_key)
                gate_echo(
                    "   max import ${max_ver} — provided by ${resolved_${soname_key}}")
            endif()
        endforeach()
    endif()
endforeach()

gate_echo("----------------------------------------------------------------------")
if(failures GREATER 0)
    message(
        FATAL_ERROR
        "ABI gate FAILED — ${failures} of ${binary_count} binaries incompatible with this runtime")
endif()
message(
    STATUS "ABI gate passed — ${binary_count} binaries compatible with this runtime")
