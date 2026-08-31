#!/usr/bin/env bash
# --- Windows PE import gate (Steam static-CRT check) -------------------------
# Lists every DLL each PE binary imports and fails when an import is on the
# forbidden list. Steam depots must not rely on the VC++ redistributable or
# MinGW runtime DLLs being present on the user's machine — link the C/C++
# runtime statically instead.
#
# Works with GNU objdump or llvm-objdump (set OBJDUMP=...).
#
# Usage:  check_pe_imports.sh <exe-or-dir> [more...] -- <forbidden.dll> [more...]
# Exit:   0 = clean, 1 = forbidden import found, 2 = usage error
# ----------------------------------------------------------------------------
set -euo pipefail

objdump=${OBJDUMP:-objdump}

declare -a targets=()
declare -a forbidden=()
seen_separator=0
for arg in "$@"; do
    if [[ $arg == "--" ]]; then
        seen_separator=1
        continue
    fi
    if ((seen_separator)); then
        forbidden+=("$arg")
    else
        targets+=("$arg")
    fi
done

if ((${#targets[@]} == 0 || ${#forbidden[@]} == 0)); then
    echo "usage: OBJDUMP=objdump $0 <exe-or-dir> [more...] -- <forbidden.dll> [more...]" >&2
    exit 2
fi

if ! command -v "$objdump" > /dev/null 2>&1; then
    echo "::error::objdump not found: $objdump (set OBJDUMP=...)" >&2
    exit 2
fi

is_pe() { [[ $(head -c 2 -- "$1") == "MZ" ]]; }

declare -a pefiles=()
for target in "${targets[@]}"; do
    if [[ -d $target ]]; then
        while IFS= read -r -d '' file; do
            if is_pe "$file"; then
                pefiles+=("$file")
            fi
        done < <(find "$target" -type f \( -name '*.exe' -o -name '*.dll' \) -print0)
    elif [[ -f $target ]]; then
        if is_pe "$target"; then
            pefiles+=("$target")
        fi
    else
        echo "::error::no such file or directory: $target" >&2
        exit 2
    fi
done

if ((${#pefiles[@]} == 0)); then
    echo "::error::no PE binaries found under: ${targets[*]}" >&2
    exit 1
fi

failures=0
for pe in "${pefiles[@]}"; do
    echo "-- ${pe}"
    declare -a imports=()
    mapfile -t imports < <("$objdump" -p -- "$pe" | grep -iE '^[[:space:]]*DLL Name:' | awk '{print $3}' | sort -u)
    if ((${#imports[@]} == 0)); then
        echo "   no DLL imports — fully static, OK"
        continue
    fi
    printf '   %s\n' "${imports[@]}"
    for dll in "${imports[@]}"; do
        for bad in "${forbidden[@]}"; do
            if [[ ${dll,,} == "${bad,,}" ]]; then
                echo "::error file=${pe}::forbidden import '${dll}' — link the C/C++ runtime statically for Steam"
                failures=$((failures + 1))
            fi
        done
    done
done

echo "----------------------------------------------------------------------------"
if ((failures > 0)); then
    echo "::error::PE import gate FAILED — ${failures} forbidden import(s)"
    exit 1
fi
echo "PE import gate passed — ${#pefiles[@]} binaries clean"
