# ─── macOS Cross-Compilation Toolchain (Linux → macOS) ─────────────
# Fully automatic: downloads osxcross, a community-hosted macOS SDK,
# and builds compiler-rt for Darwin targets. Configures CMake to
# cross-compile using the host clang with --target= injection.
#
# Architecture: uses the HOST clang directly (not osxcross wrapper
# scripts) with --target= and -B for tool discovery. This is the
# same pattern as the llvm-mingw toolchain and avoids all wrapper
# script path resolution issues.
#
# Supports targets: x86_64 (Intel), arm64 (Apple Silicon)
#
# Usage:
#   # Intel Mac (default):
#   cmake -S . -B build --toolchain cmake/toolchains/macos.cmake
#
#   # Apple Silicon:
#   cmake -S . -B build --toolchain cmake/toolchains/macos.cmake \
#         -DCMAKE_SYSTEM_PROCESSOR=arm64
#
#   # Custom SDK version:
#   cmake -S . -B build --toolchain cmake/toolchains/macos.cmake \
#         -DOSXCROSS_SDK_VERSION=14.0
#
# All self-relative paths use CMAKE_CURRENT_LIST_DIR — the ONLY
# variable invariant during try_compile() re-processing.
# CMAKE_SOURCE_DIR, CMAKE_BINARY_DIR, and CMAKE_CURRENT_BINARY_DIR
# all change to temporary directories during try_compile(), which
# would cause re-downloading/re-building the toolchain for EACH of
# the hundreds of try_compile probes.
#
# Legal: The macOS SDK is Apple proprietary. This toolchain downloads
# from a community archive on GitHub. Use at your own discretion.
#
# Ref: https://github.com/tpoechtrager/osxcross
#      https://github.com/joseluisq/macosx-sdks
#      https://clang.llvm.org/docs/CrossCompilation.html
# ───────────────────────────────────────────────────────────────────

set(CMAKE_SYSTEM_NAME "Darwin")

if(NOT CMAKE_SYSTEM_PROCESSOR)
    set(CMAKE_SYSTEM_PROCESSOR "x86_64")
endif()

# ─── Configurable SDK version ─────────────────────────────────────
# Community-hosted SDKs available at joseluisq/macosx-sdks:
#   12.3, 13.3, 14.0, 14.5, 15.0, 15.2 (check repo for latest)
#
# SDK 15.2 (Xcode 16.x) ships libc++ based on LLVM 18+, which
# includes <print>, <expected>, and other C++23 library features.
# SDK 14.0 (Xcode 15.0) ships libc++ based on LLVM 16, which
# does NOT have <print>.
if(NOT OSXCROSS_SDK_VERSION)
    set(OSXCROSS_SDK_VERSION "15.2")
endif()

if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0")
endif()

# ─── Toolchain root ───────────────────────────────────────────────
set(osx_root "${CMAKE_CURRENT_LIST_DIR}/osxcross_toolchain")

# ─── Auto-download SDK + osxcross, build toolchain ────────────────
# Guarded by directory existence. After the first successful build,
# this entire block is skipped — including during the hundreds of
# try_compile() re-processing cycles (~0ms overhead).
# ───────────────────────────────────────────────────────────────────
if(NOT IS_DIRECTORY "${osx_root}/bin")

    find_program(osx_build_clang NAMES clang)
    if(NOT osx_build_clang)
        message(
            FATAL_ERROR
                "Host 'clang' is required to build osxcross.\n"
                "Install:\n"
                "  Ubuntu: sudo apt install clang llvm-dev libxml2-dev "
                "libssl-dev liblzma-dev libbz2-dev cmake patch make\n"
                "  Fedora: sudo dnf install clang llvm-devel libxml2-devel "
                "openssl-devel xz-devel cmake patch make")
    endif()

    # ── Save caller's FetchContent state ───────────────────
    # Toolchain files run in caller's scope via include().
    # FETCHCONTENT_BASE_DIR set here leaks into the main
    # project and corrupts CPM's FetchContent downloads.
    # On subsequent configures this block is skipped so the
    # variable reverts to default — causing CPM to look in
    # a different directory and fail with:
    #   "Unknown CMake command cpmaddpackage"
    set(osx_saved_fc_basedir "${FETCHCONTENT_BASE_DIR}")
    set(osx_saved_fc_quiet "${FETCHCONTENT_QUIET}")

    set(FETCHCONTENT_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}/.macos-toolchain-deps")
    set(FETCHCONTENT_QUIET OFF)

    include(FetchContent)

    # ── Download macOS SDK ─────────────────────────────────
    # Community-maintained SDK archives extracted from publicly
    # available Xcode downloads and re-hosted on GitHub.
    # Ref: https://github.com/joseluisq/macosx-sdks
    set(osx_sdk_url
        "https://github.com/joseluisq/macosx-sdks/releases/download/${OSXCROSS_SDK_VERSION}/MacOSX${OSXCROSS_SDK_VERSION}.sdk.tar.xz"
        )
    set(osx_sdk_cache_dir "${CMAKE_CURRENT_LIST_DIR}/.macos-sdk-cache")
    set(osx_sdk_tarball
        "${osx_sdk_cache_dir}/MacOSX${OSXCROSS_SDK_VERSION}.sdk.tar.xz")

    if(NOT EXISTS "${osx_sdk_tarball}")
        message(STATUS "Downloading macOS ${OSXCROSS_SDK_VERSION} SDK...")
        file(MAKE_DIRECTORY "${osx_sdk_cache_dir}")
        file(DOWNLOAD "${osx_sdk_url}" "${osx_sdk_tarball}" SHOW_PROGRESS
             STATUS osx_sdk_dl_status)
        list(
            GET
            osx_sdk_dl_status
            0
            osx_sdk_dl_code)
        if(NOT
           osx_sdk_dl_code
           EQUAL
           0)
            list(
                GET
                osx_sdk_dl_status
                1
                osx_sdk_dl_msg)
            file(REMOVE "${osx_sdk_tarball}")
            message(
                FATAL_ERROR
                    "macOS SDK download failed: ${osx_sdk_dl_msg}\n"
                    "URL: ${osx_sdk_url}\n"
                    "\n"
                    "Check available versions at:\n"
                    "  https://github.com/joseluisq/macosx-sdks/releases\n"
                    "\n"
                    "Or provide your own SDK tarball:\n"
                    "  -DOSXCROSS_SDK_TARBALL=/path/to/MacOSX<ver>.sdk.tar.xz")
        endif()
    else()
        message(STATUS "Using cached macOS SDK: ${osx_sdk_tarball}")
    endif()

    # ── Download osxcross source ───────────────────────────
    # osxcross provides cctools-port (Apple's ld64, ar, etc.
    # ported to Linux) and triple-prefixed clang wrappers.
    fetchcontent_declare(
        osxcross_src
        GIT_REPOSITORY "https://github.com/tpoechtrager/osxcross.git"
        GIT_TAG "master"
        GIT_SHALLOW TRUE
        GIT_PROGRESS TRUE
        SOURCE_DIR
        "${CMAKE_CURRENT_LIST_DIR}/.osxcross-src"
        SOURCE_SUBDIR
        __do_not_add_as_subdirectory__)

    fetchcontent_makeavailable(osxcross_src)

    # ── Place SDK tarball where osxcross expects it ────────
    # osxcross expects the SDK in its tarballs/ directory.
    # Symlink/copy instead of duplicating the ~500MB file.
    file(MAKE_DIRECTORY "${osxcross_src_SOURCE_DIR}/tarballs")
    get_filename_component(osx_sdk_filename "${osx_sdk_tarball}" NAME)
    set(osx_sdk_link "${osxcross_src_SOURCE_DIR}/tarballs/${osx_sdk_filename}")
    if(NOT EXISTS "${osx_sdk_link}")
        file(
            CREATE_LINK
            "${osx_sdk_tarball}"
            "${osx_sdk_link}"
            COPY_ON_ERROR)
    endif()

    # ── Build osxcross ─────────────────────────────────────
    # UNATTENDED=1           Skips confirmation prompts.
    # TARGET_DIR             Where to install the built toolchain.
    # ENABLE_CLANG_INSTALL=0 Don't rebuild clang — use host.
    #
    # This takes 2-5 minutes on first run.
    message(STATUS "Building osxcross → ${osx_root}")
    message(STATUS "This may take several minutes on first run...")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env "UNATTENDED=1" "TARGET_DIR=${osx_root}"
            "ENABLE_CLANG_INSTALL=0" bash ./build.sh
        WORKING_DIRECTORY "${osxcross_src_SOURCE_DIR}"
        RESULT_VARIABLE osx_build_result
        ERROR_VARIABLE osx_build_error)

    if(NOT
       osx_build_result
       EQUAL
       0)
        file(REMOVE_RECURSE "${osx_root}")
        message(
            FATAL_ERROR
                "osxcross build failed (exit code: ${osx_build_result}).\n"
                "\n"
                "stderr:\n${osx_build_error}\n"
                "\n"
                "Ensure host build dependencies are installed:\n"
                "  Ubuntu: sudo apt install clang llvm-dev libxml2-dev\n"
                "          libssl-dev liblzma-dev libbz2-dev cmake "
                "patch make\n"
                "  Fedora: sudo dnf install clang llvm-devel "
                "libxml2-devel\n"
                "          openssl-devel xz-devel cmake patch make")
    endif()

    message(STATUS "osxcross built successfully at ${osx_root}")

    # ── Build compiler-rt for Darwin targets ───────────────
    # macOS Objective-C code using @available() compiles to
    # calls to ___isPlatformVersionAtLeast, which lives in
    # libclang_rt.osx.a (LLVM compiler-rt builtins for Darwin).
    #
    # The host clang on Linux only ships Linux builtins. When
    # cross-compiling for macOS, the linker can't find the
    # Darwin builtins → undefined symbol error:
    #   "___isPlatformVersionAtLeast", referenced from:
    #       SDL_cocoaevents.m.o
    #       SDL_cocoawindow.m.o
    #       SDL_camera_coremedia.m.o
    #
    # osxcross provides build_compiler_rt.sh which downloads
    # LLVM source and cross-builds the Darwin builtins using
    # the osxcross wrappers.
    #
    # We install into a LOCAL copy of the host clang's
    # resource directory so no sudo is needed. The host
    # resource dir is typically /usr/lib/clang/<ver>/ which
    # is read-only. --resource-dir in FLAGS_INIT tells clang
    # to use our local copy instead of the system one.
    #
    # This downloads LLVM source and builds compiler-rt
    # (~5-10 minutes on first run, cached thereafter).
    # Ref: https://github.com/tpoechtrager/osxcross#compiler-rt
    # ───────────────────────────────────────────────────────

    # Get host clang's resource directory path.
    execute_process(
        COMMAND "${osx_build_clang}" -print-resource-dir
        OUTPUT_VARIABLE osx_host_resource_dir OUTPUT_STRIP_TRAILING_WHITESPACE)

    set(osx_local_resource_dir "${osx_root}/clang-rt")

    # Copy the host clang's resource dir (headers, Linux
    # sanitizer runtimes, etc.) to a local writable location.
    if(NOT IS_DIRECTORY "${osx_local_resource_dir}")
        file(COPY "${osx_host_resource_dir}/"
             DESTINATION "${osx_local_resource_dir}")
    endif()

    if(NOT EXISTS "${osx_local_resource_dir}/lib/darwin/libclang_rt.osx.a")
        message(STATUS "Building compiler-rt for Darwin targets...")
        message(STATUS "This downloads LLVM source — may take 5-10 minutes...")

        execute_process(
            COMMAND
                "${CMAKE_COMMAND}" -E env "OSXCROSS_TARGET_DIR=${osx_root}"
                "INSTALLPREFIX=${osx_local_resource_dir}" bash
                ./build_compiler_rt.sh
            WORKING_DIRECTORY "${osxcross_src_SOURCE_DIR}"
            RESULT_VARIABLE osx_rt_result
            ERROR_VARIABLE osx_rt_error)

        if(NOT
           osx_rt_result
           EQUAL
           0)
            message(
                WARNING
                    "compiler-rt build failed (exit code: ${osx_rt_result}).\n"
                    "@available() calls in Objective-C will cause linker errors.\n"
                    "\n"
                    "stderr:\n${osx_rt_error}\n"
                    "\n"
                    "Try manually:\n"
                    "  cd ${osxcross_src_SOURCE_DIR}\n"
                    "  OSXCROSS_TARGET_DIR=${osx_root} "
                    "./build_compiler_rt.sh")
        else()
            message(STATUS "compiler-rt built successfully")
        endif()
    else()
        message(STATUS "Using cached compiler-rt: ${osx_local_resource_dir}")
    endif()

    # ── Restore caller's FetchContent state ────────────────
    set(FETCHCONTENT_BASE_DIR "${osx_saved_fc_basedir}")
    set(FETCHCONTENT_QUIET "${osx_saved_fc_quiet}")
    unset(osx_saved_fc_basedir)
    unset(osx_saved_fc_quiet)
endif()

# ─── Discover target triple from installed tools ──────────────────
# osxcross names wrappers: <arch>-apple-darwin<ver>-<tool>
# The darwin version comes from the SDK:
#   darwin21 = macOS 12, darwin22 = macOS 13, darwin23 = macOS 14,
#   darwin24 = macOS 15
#
# We scan bin/ to find the actual triple rather than computing it,
# which is fragile and breaks across SDK releases.
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
    set(osx_arch_prefix "aarch64")
else()
    set(osx_arch_prefix "${CMAKE_SYSTEM_PROCESSOR}")
endif()

file(GLOB osx_compiler_matches
     "${osx_root}/bin/${osx_arch_prefix}-apple-darwin*-clang")

if(NOT osx_compiler_matches)
    file(GLOB osx_all_compilers "${osx_root}/bin/*-apple-darwin*-clang")
    string(
        REPLACE ";"
                "\n  "
                osx_tools_list
                "${osx_all_compilers}")
    message(
        FATAL_ERROR
            "No osxcross compiler found for '${osx_arch_prefix}' in:\n"
            "  ${osx_root}/bin/\n"
            "\n"
            "Available compilers:\n  ${osx_tools_list}\n"
            "\n"
            "Valid CMAKE_SYSTEM_PROCESSOR: x86_64, arm64, aarch64")
endif()

# If multiple darwin versions exist, pick the highest.
list(SORT osx_compiler_matches ORDER DESCENDING)
list(
    GET
    osx_compiler_matches
    0
    osx_selected_compiler)

get_filename_component(osx_compiler_filename "${osx_selected_compiler}" NAME)
string(
    REGEX MATCH
          "^([a-z0-9_]+-apple-darwin[0-9]+)"
          osx_triple
          "${osx_compiler_filename}")

if(NOT osx_triple)
    message(
        FATAL_ERROR "Could not extract triple from: ${osx_compiler_filename}")
endif()

message(STATUS "osxcross triple: ${osx_triple}")

# ─── macOS SDK (sysroot) ──────────────────────────────────────────
file(GLOB osx_sdk_dirs "${osx_root}/SDK/MacOSX*.sdk")
if(NOT osx_sdk_dirs)
    message(FATAL_ERROR "No macOS SDK found in ${osx_root}/SDK/")
endif()
list(SORT osx_sdk_dirs ORDER DESCENDING)
list(
    GET
    osx_sdk_dirs
    0
    osx_sdk_path)

set(CMAKE_OSX_SYSROOT "${osx_sdk_path}")

# ─── Compilers: host clang + --target= (NOT wrapper scripts) ──────
# The osxcross wrapper scripts (x86_64-apple-darwin24-clang) are
# shell scripts that call the host's actual clang binary. The
# problem: the host clang doesn't know to look in osxcross/bin/
# for the cctools ld64 port. It falls back to /usr/bin/ld (GNU ld),
# which only understands ELF:
#   "unrecognised emulation mode: llvm"
#
# Fix: use the host clang directly with:
#   CMAKE_<LANG>_COMPILER_TARGET → injects --target=<triple>
#   -B<osxcross/bin>             → tells clang where cross tools live
#   -fuse-ld=<path>              → forces specific linker binary
#   --resource-dir=<path>        → finds Darwin compiler-rt builtins
#
# This is the SAME pattern as the llvm-mingw toolchain.
#
# CRITICAL: macOS targets use Objective-C (.m) and Objective-C++
# (.mm) for platform-specific code (SDL3 camera, windowing, menus,
# etc.). CMake treats OBJC and OBJCXX as SEPARATE LANGUAGES from
# C and CXX. Each needs its own COMPILER and COMPILER_TARGET —
# without it, the host clang doesn't inject --target=, selects the
# GNU ObjC runtime (legacy), and -fobjc-arc fails with:
#   "error: -fobjc-arc is not supported on platforms using the
#    legacy runtime"
#
# Ref: https://clang.llvm.org/docs/CrossCompilation.html
#      https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_COMPILER_TARGET.html
# ───────────────────────────────────────────────────────────────────
find_program(osx_host_cc NAMES clang)
find_program(osx_host_cxx NAMES clang++)

if(NOT osx_host_cc OR NOT osx_host_cxx)
    message(
        FATAL_ERROR
            "Host clang/clang++ not found. Required for cross-compilation.\n"
            "  Ubuntu: sudo apt install clang\n"
            "  Fedora: sudo dnf install clang")
endif()

# C
set(CMAKE_C_COMPILER "${osx_host_cc}")
set(CMAKE_C_COMPILER_TARGET "${osx_triple}")

# C++
set(CMAKE_CXX_COMPILER "${osx_host_cxx}")
set(CMAKE_CXX_COMPILER_TARGET "${osx_triple}")

# Objective-C (SDL3 .m files: camera, windowing, clipboard, etc.)
set(CMAKE_OBJC_COMPILER "${osx_host_cc}")
set(CMAKE_OBJC_COMPILER_TARGET "${osx_triple}")

# Objective-C++ (SDL3 .mm files, Qt, any Cocoa-using library)
set(CMAKE_OBJCXX_COMPILER "${osx_host_cxx}")
set(CMAKE_OBJCXX_COMPILER_TARGET "${osx_triple}")

# ─── Common compiler flags ────────────────────────────────────────
# -B<dir>: tells clang where to find cross tools (ld64, ar, etc.)
# --resource-dir=<dir>: tells clang where to find compiler-rt
#   builtins for Darwin. Without this, clang looks in the host's
#   resource dir which only has Linux builtins →
#   ___isPlatformVersionAtLeast undefined at link time.
#
# _INIT variants are mandatory in toolchain files — they set the
# initial value of CMAKE_<LANG>_FLAGS on first configure. They do
# NOT override cached values from previous configures, which is why
# a build directory wipe is required after toolchain changes.
# Ref: https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_FLAGS_INIT.html
set(osx_local_resource_dir "${osx_root}/clang-rt")

if(IS_DIRECTORY "${osx_local_resource_dir}/lib/darwin")
    set(osx_common_flags
        "-B${osx_root}/bin --resource-dir=${osx_local_resource_dir}")
else()
    set(osx_common_flags "-B${osx_root}/bin")
endif()

set(CMAKE_C_FLAGS_INIT "${osx_common_flags}")
set(CMAKE_CXX_FLAGS_INIT "${osx_common_flags}")
set(CMAKE_OBJC_FLAGS_INIT "${osx_common_flags}")
set(CMAKE_OBJCXX_FLAGS_INIT "${osx_common_flags}")

# ─── Explicit linker specification ─────────────────────────────────
# -fuse-ld=<path>: forces specific linker binary (cctools ld64).
# --resource-dir=<path>: tells clang where compiler-rt builtins
#   live. CRITICAL: this must be in LINKER flags too, not just
#   compile flags. When clang acts as the linker driver, it reads
#   --resource-dir to find libclang_rt.osx.a and passes it to the
#   linker automatically. CMAKE_C_FLAGS_INIT only applies to compile
#   commands — CMake does NOT forward compile flags to link commands.
#   Without --resource-dir in linker flags:
#     "___isPlatformVersionAtLeast" → undefined symbol
#
# Ref: https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_FLAGS_INIT.html
set(osx_local_resource_dir "${osx_root}/clang-rt")

set(osx_linker_flags "-fuse-ld=${osx_root}/bin/${osx_triple}-ld")

if(IS_DIRECTORY "${osx_local_resource_dir}/lib/darwin")
    string(APPEND osx_linker_flags " --resource-dir=${osx_local_resource_dir}")
endif()

set(CMAKE_EXE_LINKER_FLAGS_INIT "${osx_linker_flags}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${osx_linker_flags}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${osx_linker_flags}")

# ─── Cross-compilation tools (cctools-port) ────────────────────────
# osxcross ships cctools-port: Apple's build tools (ar, ranlib,
# strip, etc.) ported to Linux. Triple-prefixed for multi-arch.
set(CMAKE_AR "${osx_root}/bin/${osx_triple}-ar")
set(CMAKE_RANLIB "${osx_root}/bin/${osx_triple}-ranlib")
set(CMAKE_STRIP "${osx_root}/bin/${osx_triple}-strip")
set(CMAKE_NM "${osx_root}/bin/${osx_triple}-nm")

# install_name_tool: macOS equivalent of patchelf. Modifies
# LC_RPATH, LC_ID_DYLIB, and LC_LOAD_DYLIB in Mach-O binaries.
set(CMAKE_INSTALL_NAME_TOOL "${osx_root}/bin/${osx_triple}-install_name_tool")

# dsymutil: extracts dSYM debug symbol bundles from Mach-O
# binaries. macOS equivalent of Windows PDB files.
set(CMAKE_DSYMUTIL "${osx_root}/bin/${osx_triple}-dsymutil")

# lipo: creates/manipulates Universal (fat) binaries.
set(CMAKE_LIPO "${osx_root}/bin/${osx_triple}-lipo")

# ─── Search-path isolation ────────────────────────────────────────
# Prevent find_*() from accidentally finding host Linux packages.
set(CMAKE_FIND_ROOT_PATH "${osx_root}" "${osx_sdk_path}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ─── C++ standards ─────────────────────────────────────────────────
# Disable C++20 module scanning — extremely slow against a foreign
# sysroot and provides zero value when modules are not used.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Strict ISO C++ (no GNU extensions): -std=c++23, not -std=gnu++23.
set(CMAKE_CXX_EXTENSIONS OFF)

# ─── Compile-only try_compile probes ──────────────────────────────
# SDL3 and other dependencies run hundreds of feature-detection
# probes. STATIC_LIBRARY mode compiles to .o → archives to .a —
# no linker invocation, dramatically faster.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
