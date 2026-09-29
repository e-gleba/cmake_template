cmake_minimum_required(VERSION 4.3)

project(
    rt_demo
    VERSION 0.1.0
    DESCRIPTION "minimal runtime-deps bundling demo"
    HOMEPAGE_URL "https://github.com/e-gleba/cmake_template"
    LANGUAGES C CXX)

# No C++20 modules in use — do not pay for the module dependency scan.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

include(GNUInstallDirs)

# ── Fail fast when libc++ is requested but unusable ───────────────────
# -stdlib=libc++ needs libc++ headers + libs for the ACTIVE compiler
# (mise: conda-forge libcxx + libcxx-devel via RT_LIBCXX_* in mise.toml;
# system: libcxx-devel / libc++-dev). Without this check a missing libc++
# surfaces late as `ld: cannot find -lc++`. The check reuses exactly the
# flags the target will build with, forwarded via CMAKE_FLAGS.
if(CMAKE_CXX_FLAGS MATCHES "stdlib=libc\\+\\+")
    set(rt_libcxx_check_src "${PROJECT_BINARY_DIR}/rt_libcxx_check.cpp")
    file(WRITE "${rt_libcxx_check_src}" "int main(){return 0;}\n")
    try_compile(
        rt_libcxx_ok
        "${PROJECT_BINARY_DIR}/rt_libcxx_check"
        SOURCES "${rt_libcxx_check_src}"
        CMAKE_FLAGS "-DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}"
                    "-DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}"
        OUTPUT_VARIABLE rt_libcxx_log)
    if(NOT rt_libcxx_ok)
        message(
            FATAL_ERROR
                "rt_demo: -stdlib=libc++ requested but the active compiler cannot build it.\n"
                "With mise: run `mise install` in this directory (provides conda-forge libcxx).\n"
                "On a system compiler: Fedora `dnf install libcxx-devel`, Ubuntu `apt install libc++-dev`.\n"
                "Probe output:\n${rt_libcxx_log}")
    endif()
endif()

# ── Runtime policy ────────────────────────────────────────────────────
# OFF (default): dynamic-link the C++ runtime and bundle the non-system
#   DLLs/so via RUNTIME_DEPENDENCY_SET below. This is what this demo
#   exercises — the installed bin/ + lib/ tree must run on a clean
#   machine of the same OS family.
# ON: static-link the runtime instead (no bundled libc++/libunwind).
#   This matches the Steam depot policy in the parent template
#   (src/*/CMakeLists.txt: Windows GNU-frontend exes link -static).
option(RT_STATIC_RUNTIME "Static-link the C++ runtime (ship no runtime DLLs/so)"
       OFF)

add_executable(rt_demo)
add_executable(rt::demo ALIAS rt_demo)
target_sources(rt_demo PRIVATE main.cpp)
target_compile_features(rt_demo PRIVATE cxx_std_23)
set_target_properties(
    rt_demo PROPERTIES CXX_EXTENSIONS OFF BUILD_RPATH_USE_ORIGIN TRUE
                       BUILD_WITH_INSTALL_RPATH FALSE
                       # $ORIGIN elsewhere, @loader_path on Apple — same
                       # genex as src/02_sdl3_app. INSTALL_RPATH supports
                       # genexes (CMP0095 NEW at our 4.3 floor escapes
                       # $ORIGIN correctly in the install script).
                       INSTALL_RPATH
                       "$<IF:$<PLATFORM_ID:Darwin>,@loader_path,$ORIGIN>/../${CMAKE_INSTALL_LIBDIR}"
)
target_compile_options(
    rt_demo
    PRIVATE $<$<CXX_COMPILER_ID:Clang,AppleClang>:-Wall;-Wextra;-Wpedantic>
            $<$<CXX_COMPILER_ID:GNU>:-Wall;-Wextra;-Wpedantic>
            $<$<CXX_COMPILER_ID:MSVC>:/W4>)

# Steam depot policy, opt-in here: Windows GNU-frontend exes link the
# non-system runtimes (libc++/libunwind/libstdc++/libgcc) statically —
# UCRT stays a dynamic Windows system import. MSVC / clang-cl (MSVC
# frontend) and non-Windows never match. MSVC static CRT is a cache
# variable, not a target flag: -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded.
target_link_options(
    rt_demo PRIVATE
    "$<$<AND:$<BOOL:${RT_STATIC_RUNTIME}>,$<PLATFORM_ID:Windows>,$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>,$<C_COMPILER_FRONTEND_VARIANT:GNU>>:$<LINK_ONLY:-static>>"
)

install(
    TARGETS rt_demo
    RUNTIME_DEPENDENCY_SET rt_deps
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}" COMPONENT runtime)

# ── Bundle the C++ runtime, exclude the OS ────────────────────────────
# Bundled (NOT excluded) per toolchain — this is the point of the demo:
#   Clang + libstdc++ : libstdc++.so.6 + libgcc_s.so.1
#   Clang + libc++    : libc++.so.1 + libc++abi.so.1 (+ libunwind.so.1
#                       when the libc++ build uses it)
#   llvm-mingw (dynamic)  : libc++.dll + libunwind.dll + libgcc_s_seh-1.dll
#   MSVC (dynamic)        : vcruntime140.dll + msvcp140.dll
# Excluded: the kernel loader + libc/libm + legacy threading libs (now
# part of libc on modern glibc) + Windows system32 DLLs. libgcc_s and
# the C++ runtimes above must NEVER appear here — excluding them is the
# classic bug that produces a package which runs only on the build host.
# DIRECTORIES must list the compiler's implicit link dirs, otherwise
# file(GET_RUNTIME_DEPENDENCIES) cannot resolve libc++/libstdc++ found
# via -stdlib=libc++ or the default search path. Verified with:
#   cmake -S . -B build --trace-expand 2>&1 | grep -i runtime
install(
    RUNTIME_DEPENDENCY_SET
    rt_deps
    PRE_EXCLUDE_REGEXES
        [[ld-linux.*]]
        [[libc\.so.*]]
        [[libm\.so.*]]
        [[libpthread.*]]
        [[libdl\.so.*]]
        [[librt\.so.*]]
        [[libresolv\.so.*]]
        [[api-ms-win-.*]]
        [[ext-ms-.*]]
    POST_EXCLUDE_REGEXES
        [[ld-linux.*]]
        [[libc\.so.*]]
        [[libm\.so.*]]
        [[libpthread.*]]
        [[libdl\.so.*]]
        [[librt\.so.*]]
        [[libresolv\.so.*]]
        [[api-ms-win-.*]]
        [[ext-ms-.*]]
        [[.*/system32/.*]]
    DIRECTORIES
        ${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}
        ${CMAKE_C_IMPLICIT_LINK_DIRECTORIES}
    DESTINATION
        ${CMAKE_INSTALL_LIBDIR}
    COMPONENT
        runtime)

# ── Windows: stage runtime DLLs next to the .exe for build-tree runs ──
# $<TARGET_RUNTIME_DLLS> expands to nothing on other platforms, but
# guarding keeps the custom command out of non-Windows build graphs.
# Skipped when RT_STATIC_RUNTIME=ON (fully static — nothing to stage).
if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND NOT RT_STATIC_RUNTIME)
    add_custom_command(
        TARGET rt_demo
        POST_BUILD
        COMMAND
            ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:rt_demo>
            $<TARGET_RUNTIME_DLLS:rt_demo>
        COMMAND_EXPAND_LISTS)
endif()

if(PROJECT_IS_TOP_LEVEL)
    # ── CPack: file name os_compiler_arch ─────────────────────────────
    # Same scheme as cmake/cpack/ct_cpack.cmake in the parent template:
    # the compiler tag keeps GCC vs Clang packages apart, the arch tag
    # keeps cross builds apart (x86_64 vs aarch64).
    set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
    set(CPACK_PACKAGE_VENDOR "rt_demo")
    set(CPACK_PACKAGE_CONTACT "me@example.com")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
    set(CPACK_VERBATIM_VARIABLES YES)
    set(CPACK_STRIP_FILES TRUE)
    # SHLIBDEPS OFF on purpose: the bundle SHIPS its runtime in lib/,
    # so the .deb must not Declare a Depends on the host's libstdc++6 —
    # the two mechanisms conflict. System .debs use ON; portable
    # bundles like this one use OFF.
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)
    set(CPACK_SYSTEM_NAME
        "${CMAKE_SYSTEM_NAME}_${CMAKE_CXX_COMPILER_ID}_${CMAKE_SYSTEM_PROCESSOR}"
    )
    if(NOT DEFINED CPACK_GENERATOR)
        set(CPACK_GENERATOR "TGZ;DEB")
    endif()
    # include(CPack) reads all CPACK_* variables at include-time and
    # ignores later changes — keep it last.
    include(CPack)
endif()
