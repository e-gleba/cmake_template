# fmt wrapper (find_package(fmt CONFIG)). NOTE the filename matters:
# find_package(fmt) only loads fmt-config.cmake / Findfmt.cmake.
#
# 32-BIT LIMITATION: do NOT consume fmt from 32-bit targets
# (e.g. windows_llvm_mingw_x86). fmt 12 does not compile there at all —
# even a trivial print of a string_view fails: its uint128 software
# fallback (no __int128 on 32-bit) lacks operator~, breaking
# format_hexfloat<long double>, which basic_format_arg::visit()
# instantiates for EVERY formatting call. FMT_USE_LONG_DOUBLE=0 does
# not avoid it. fmt 11 fails there too (different error). 08 therefore
# stays dependency-free std. Revisit if upstream fixes 32-bit support.
#
# 64-bit consumers: link ct_fmt_header_only below — header-only, so the
# compiled lib (format.cc) is never built and no libstdc++/libc++ ABI
# boundary exists at link time.
cpmaddpackage(
    NAME
    fmt
    GITHUB_REPOSITORY
    fmtlib/fmt
    GIT_TAG
    12.2.0
    GIT_SHALLOW
    ON
    GIT_PROGRESS
    ON
    EXCLUDE_FROM_ALL
    YES
    SYSTEM
    YES
    OPTIONS
    "FMT_DOC OFF"
    "FMT_TEST OFF"
    "FMT_INSTALL OFF")

if(NOT TARGET ct_fmt_header_only)
    add_library(ct_fmt_header_only INTERFACE)
    target_include_directories(
        ct_fmt_header_only SYSTEM INTERFACE "${fmt_SOURCE_DIR}/include")
    # fmt's documented header-only mode: templates instantiate in the
    # consumer's TUs with the consumer's stdlib — nothing to link.
    target_compile_definitions(ct_fmt_header_only INTERFACE FMT_HEADER_ONLY)
endif()
