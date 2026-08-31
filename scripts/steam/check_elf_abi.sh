#!/usr/bin/env bash
# --- Steam Runtime ABI gate -------------------------------------------------
# Verifies ELF binaries against the shared libraries of the runtime they
# currently execute in. Two checks per binary:
#
#   1. Resolution — every NEEDED entry must resolve (ldd shows no
#      "not found"). The resolved paths are printed: evidence of WHERE the
#      loader takes each library from.
#   2. Symbol versions — every versioned symbol the binary REQUIRES
#      (GLIBC_*, GLIBCXX_*, CXXABI_*, GCC_*) must be PROVIDED by the
#      runtime's own libc.so.6 / libstdc++.so.6 / libgcc_s.so.1.
#      Catches "built on a newer distro" breakage before SteamPipe does.
#
# No version is hardcoded — the runtime under test is the baseline.
# Run inside the steamrt4 SDK container (build-time gate) or on any machine
# whose libraries you want to validate against.
#
# Usage:  check_elf_abi.sh <elf-file-or-dir> [more...]
# Exit:   0 = all binaries compatible, 1 = violation found, 2 = usage error
# ----------------------------------------------------------------------------
set -euo pipefail

if (($# == 0)); then
    echo "usage: $0 <elf-file-or-dir> [more...]" >&2
    exit 2
fi

for tool in objdump ldd find od; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "::error::required tool not found in PATH: $tool" >&2
        exit 2
    fi
done

# ELF magic + e_type: 2 = executable, 3 = shared object/PIE.
# Relocatable objects (e_type 1, e.g. .o files in _deps) are skipped.
is_elf() {
    [[ $(head -c 4 -- "$1") == $'\x7fELF' ]] || return 1
    local elf_type
    elf_type=$(od -An -j 16 -N 1 -t u1 -- "$1" | tr -d '[:space:]')
    [[ $elf_type == 2 || $elf_type == 3 ]]
}

# --- Collect ELF binaries ----------------------------------------------------
declare -a binaries=()
for arg in "$@"; do
    if [[ -d $arg ]]; then
        while IFS= read -r -d '' file; do
            if is_elf "$file"; then
                binaries+=("$file")
            fi
        done < <(find "$arg" -type f -print0)
    elif [[ -f $arg ]]; then
        if is_elf "$arg"; then
            binaries+=("$arg")
        fi
    else
        echo "::error::no such file or directory: $arg" >&2
        exit 2
    fi
done

if ((${#binaries[@]} == 0)); then
    echo "::error::no ELF binaries found under: $*" >&2
    exit 1
fi

# version-tag family -> soname of the runtime library that must provide it
soname_for_prefix() {
    case $1 in
        GLIBC) echo "libc.so.6" ;;
        GLIBCXX | CXXABI) echo "libstdc++.so.6" ;;
        GCC) echo "libgcc_s.so.1" ;;
        *) return 1 ;;
    esac
}

# all version tags present in a library's dynamic symbol table (its own
# definitions included), minus private nodes
provided_versions() {
    objdump -T -- "$1" |
        grep -oE '\b(GLIBCXX|CXXABI|GLIBC|GCC)_[0-9][0-9.]*' |
        grep -v '_PRIVATE' |
        sort -u || true
}

# version tags on the binary's UNDEFINED (imported) dynamic symbols
required_versions() {
    objdump -T -- "$1" |
        grep '\*UND\*' |
        grep -oE '\b(GLIBCXX|CXXABI|GLIBC|GCC)_[0-9][0-9.]*' |
        sort -u || true
}

failures=0

check_binary() {
    local bin=$1
    echo "-- ${bin}"

    if ! objdump -p -- "$bin" | grep -q 'NEEDED'; then
        echo "   fully static — no dynamic dependencies, OK"
        return 0
    fi

    # -- Check 1: resolution map (where the libs are taken from) --------------
    local ldd_out
    if ! ldd_out=$(ldd "$bin" 2>&1); then
        echo "::error file=${bin}::ldd failed:"
        echo "${ldd_out}"
        return 1
    fi
    echo "${ldd_out}" | sed 's/^/   /'
    if grep -q 'not found' <<< "${ldd_out}"; then
        echo "::error file=${bin}::unresolved NEEDED libraries ('not found' above)"
        return 1
    fi

    local -A resolved=()
    local line ldd_re
    ldd_re='^[[:space:]]*([^[:space:]]+)[[:space:]]+=>[[:space:]]+(/[^[:space:]]+)'
    while IFS= read -r line; do
        if [[ $line =~ $ldd_re ]]; then
            resolved[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
        fi
    done <<< "${ldd_out}"

    # -- Check 2: required symbol versions vs provided ------------------------
    local -a required=()
    mapfile -t required < <(required_versions "$bin")
    if ((${#required[@]} == 0)); then
        echo "   no versioned symbol imports, OK"
        return 0
    fi

    local -A provided_cache=()
    local ver prefix soname libpath
    local failed=0
    for ver in "${required[@]}"; do
        prefix=${ver%%_*}
        if ! soname=$(soname_for_prefix "$prefix"); then
            continue
        fi
        libpath=${resolved[$soname]:-}
        if [[ -z $libpath ]]; then
            echo "::error file=${bin}::imports ${ver} but ${soname} is not linked"
            failed=1
            continue
        fi
        if [[ -z ${provided_cache[$libpath]:-} ]]; then
            provided_cache[$libpath]=$(provided_versions "$libpath")
        fi
        if ! grep -qxF "$ver" <<< "${provided_cache[$libpath]}"; then
            echo "::error file=${bin}::imports ${ver} — not provided by ${libpath}"
            failed=1
        fi
    done
    if ((failed)); then
        return 1
    fi

    # summary: highest imported version per family and its provider
    local max
    for prefix in GLIBC GLIBCXX CXXABI GCC; do
        max=$(printf '%s\n' "${required[@]}" | grep -E "^${prefix}_" | sort -V | tail -n 1 || true)
        if [[ -n $max ]]; then
            soname=$(soname_for_prefix "$prefix")
            echo "   max import ${max} — provided by ${resolved[$soname]}"
        fi
    done
    return 0
}

for bin in "${binaries[@]}"; do
    if ! check_binary "$bin"; then
        failures=$((failures + 1))
    fi
done

echo "----------------------------------------------------------------------------"
if ((failures > 0)); then
    echo "::error::ABI gate FAILED — ${failures} of ${#binaries[@]} binaries incompatible with this runtime"
    exit 1
fi
echo "ABI gate passed — ${#binaries[@]} binaries compatible with this runtime"
