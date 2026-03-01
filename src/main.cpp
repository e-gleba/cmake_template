/**
 * @file sysinfo.cpp
 * @brief Prints system, compiler, and C++ standard information.
 *
 * Uses compile-time feature detection to select the best output path:
 *   - __cpp_lib_print  (C++23) → std::print          (<print>)
 *   - __cpp_lib_format (C++20) → std::format + cout   (<format>)
 *   - otherwise                → raw std::cout         (<iostream>)
 *
 * Flushes and checks both stdout and std::cout before exit; returns
 * EXIT_FAILURE on any I/O error (broken pipe, disk-full redirect, etc.).
 *
 * @see https://en.cppreference.com/w/cpp/utility/feature_test
 * @see https://en.cppreference.com/w/cpp/io/print
 * @see https://en.cppreference.com/w/cpp/header/version
 */

// ── Feature detection ────────────────────────────────────────────────
//
// __has_include is a C++17 feature; guard for pre-C++17 compilers.
// <version> (C++20) is the canonical home for all __cpp_lib_* macros.
// We conditionally include <print> and <format> only when the
// corresponding feature-test macro confirms availability, preventing
// hard compile errors on older toolchains.
//
#ifdef __has_include // C++17: __has_include support
#if __has_include(<version>)
#include <version> // C++20: __cpp_lib_* macros
#endif
#endif

#if defined(__cpp_lib_print) // C++23: std::print / std::println
#include <print>
#endif

#if defined(__cpp_lib_format) // C++20: std::format
#include <format>
#endif

#include <cstdio>   // std::fflush, std::ferror (stdout)
#include <cstdlib>  // EXIT_SUCCESS, EXIT_FAILURE
#include <iostream> // std::cout – fallback + health check

int main()
{
    // ── Platform detection ───────────────────────────────────────────
#if defined(_WIN32) || defined(_WIN64)
    constexpr auto os = "Windows";
#elif defined(__linux__)
    constexpr auto os = "Linux";
#elif defined(__APPLE__) && defined(__MACH__)
    constexpr auto os = "macOS";
#elif defined(__FreeBSD__)
    constexpr auto os = "FreeBSD";
#elif defined(__unix__) || defined(__unix)
    constexpr auto os = "Unix";
#else
    constexpr auto os = "Unknown";
#endif

    // ── Compiler detection ───────────────────────────────────────────
    //
    // __clang__ must be tested before __GNUC__ because Clang also
    // defines __GNUC__ for GCC compatibility.
    //
#if defined(__clang__)
    constexpr auto compiler     = "Clang";
    constexpr auto compiler_ver = __clang_major__;
#elif defined(__GNUC__)
    constexpr auto compiler     = "GCC";
    constexpr auto compiler_ver = __GNUC__;
#elif defined(_MSC_VER)
    constexpr auto compiler     = "MSVC";
    constexpr auto compiler_ver = _MSC_VER / 100;
#else
    constexpr auto compiler     = "Unknown";
    constexpr auto compiler_ver = 0;
#endif

    // ── C++ standard level ───────────────────────────────────────────
    //
    // MSVC reports __cplusplus == 199711L unless /Zc:__cplusplus is set.
    // _MSVC_LANG accurately reflects the actual standard mode.
    // @see https://learn.microsoft.com/en-us/cpp/build/reference/zc-cplusplus
    //
#if defined(_MSVC_LANG)
    constexpr auto cpp_std = _MSVC_LANG;
#else
    constexpr auto cpp_std = __cplusplus;
#endif

    // ── Tiered output ────────────────────────────────────────────────

#if defined(__cpp_lib_print)
    // C++23 path: type-safe, Unicode-aware std::print (writes to stdout).
    std::print("System Info\n");
    std::print("  OS: {}\n", os);
    std::print("  Compiler: {} {}\n", compiler, compiler_ver);
    std::print("  C++ Standard: {}\n", cpp_std);
    std::print("  std::print: supported ({})\n", __cpp_lib_print);
    std::print("\nHello, World!\n");

#elif defined(__cpp_lib_format)
    // C++20 path: std::format produces std::string, streamed to std::cout.
    std::cout << std::format("System Info\n") << std::format("  OS: {}\n", os)
              << std::format("  Compiler: {} {}\n", compiler, compiler_ver)
              << std::format("  C++ Standard: {}\n", cpp_std)
              << std::format("  std::print: not supported\n")
              << std::format("  std::format: supported ({})\n",
                             __cpp_lib_format)
              << std::format("\nHello, World!\n");

#else
    // Pre-C++20 path: raw ostream insertion operators.
    std::cout << "System Info\n"
              << "  OS: " << os << "\n"
              << "  Compiler: " << compiler << " " << compiler_ver << "\n"
              << "  C++ Standard: " << cpp_std << "\n"
              << "  std::print: not supported\n"
              << "  std::format: not supported\n"
              << "\nHello, World!\n";
#endif

    // ── Flush and verify output stream health ────────────────────────
    //
    // std::print writes to stdout (FILE*); fallback paths use std::cout.
    // These share the same underlying file descriptor but may maintain
    // independent buffers.  Flush both to ensure all pending data reaches
    // the OS, then check for I/O errors.
    //
    // Detects: broken pipe (EPIPE), disk full on redirect, permission
    //          errors, and any other write-side failures.
    //
    // @see https://en.cppreference.com/w/cpp/io/basic_ostream/flush
    // @see https://en.cppreference.com/w/cpp/io/c/fflush
    // @see https://en.cppreference.com/w/cpp/io/c/ferror
    //
    std::cout.flush();
    std::fflush(stdout);

    if (!std::cout.good() || std::ferror(stdout)) {
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
