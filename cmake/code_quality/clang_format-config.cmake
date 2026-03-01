# ─── clang-format ──────────────────────────────────────────────────
# clang-format is a host tool that reformats source files in-place.
# Unlike clang-tidy or clang-doc, it does NOT parse code against a
# sysroot, so it works correctly even when cross-compiling.
# No cross-compilation guard needed.
# ───────────────────────────────────────────────────────────────────

find_program(clang_format_exe NAMES clang-format)

if(NOT clang_format_exe)
    message(
        NOTICE
        "clang-format not found — 'clang_format' target will not be available.\n"
        "Install:\n"
        "  Fedora:  sudo dnf install clang-tools-extra\n"
        "  Ubuntu:  sudo apt install clang-format\n"
        "  macOS:   brew install llvm\n"
        "  Windows: choco install llvm")
    return()
endif()

# ── Collect source files ───────────────────────────────────────
# The original used "${PROJECT_SOURCE_DIR}/**/*.{cpp,cxx,hpp,hxx}"
# which CANNOT work:
#   1. CMake's COMMAND does not invoke a shell — globs are passed
#      as literal strings to the executable.
#   2. clang-format does not expand shell globs internally.
#   3. Brace expansion {cpp,cxx} is a bash feature, not even a
#      POSIX glob.
#
# file(GLOB_RECURSE) at configure time is acceptable here because
# this is a developer tooling target, not a compilation target.
# Worst case if a new file is added: run cmake --build --target
# clang_format after reconfiguring.
#
# CONFIGURE_DEPENDS makes Ninja/Makefiles re-glob on every build
# so new files are picked up without manual reconfigure.
#
# Adjust source directories to match your project layout.
file(
    GLOB_RECURSE
    clang_format_sources
    CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/src/*.cpp"
    "${PROJECT_SOURCE_DIR}/src/*.cxx"
    "${PROJECT_SOURCE_DIR}/src/*.hpp"
    "${PROJECT_SOURCE_DIR}/src/*.hxx"
    "${PROJECT_SOURCE_DIR}/src/*.h"
    "${PROJECT_SOURCE_DIR}/src/*.c"
    "${PROJECT_SOURCE_DIR}/include/*.hpp"
    "${PROJECT_SOURCE_DIR}/include/*.hxx"
    "${PROJECT_SOURCE_DIR}/include/*.h")

if(NOT clang_format_sources)
    message(
        NOTICE
        "clang-format: no source files found under src/ or include/. "
        "Adjust the GLOB patterns in clang_format config if your "
        "project uses different source directories.")
    return()
endif()

list(LENGTH clang_format_sources clang_format_count)

# ── Format target (modifies files in-place) ────────────────────
# Usage: cmake --build build --target clang_format
add_custom_target(
    clang_format
    COMMAND "${clang_format_exe}" -i ${clang_format_sources}
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    VERBATIM
    COMMENT "Running clang-format on ${clang_format_count} source files"
    USES_TERMINAL)

# ── Check target (CI — fails if any file needs formatting) ─────
# Usage: cmake --build build --target clang_format_check
# Returns non-zero exit code if any file would be changed.
# --dry-run: don't modify files.
# --Werror:  treat formatting differences as errors.
# Requires clang-format 10+ for --dry-run and --Werror.
add_custom_target(
    clang_format_check
    COMMAND "${clang_format_exe}" --dry-run --Werror ${clang_format_sources}
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    VERBATIM
    COMMENT "Checking clang-format compliance on ${clang_format_count} files"
    USES_TERMINAL)
