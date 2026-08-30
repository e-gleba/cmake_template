# C++20 named modules demo (issue #5). Toolchain support is probed by
# compiling a minimal module with try_compile: one ground-truth test for
# compiler, dependency scanner, generator, and build tool - no version
# matrix to maintain. Unsupported toolchains skip the target.
#
# Requirements: CMake 3.28+, Ninja 1.11+ or VS 2022 17.4+ generator,
# MSVC 14.34 / Clang 16 (with clang-scan-deps next to the compiler) /
# GCC 14. Header units are unsupported by CMake; import std is still
# experimental (CMAKE_EXPERIMENTAL_CXX_IMPORT_STD, Ninja only). The
# private module fragment unit must be the only unit of its module
# (module.private.frag) - hence the second module below.

message(CHECK_START "Checking for C++20 modules support")

# CMake added C++20 module scanning in 3.28; older CMake cannot build
# modules at all, so skip the probe (and the target) there. This also
# keeps the probe free of signatures newer than the running CMake.
if(CMAKE_VERSION VERSION_LESS 3.28)
    message(CHECK_FAIL "CMake ${CMAKE_VERSION} < 3.28 - skipping 06_modules")
    return()
endif()

# Cached like every Check* result: clear the CMake cache to re-probe
# after a toolchain change.
if(NOT DEFINED cxx_modules_supported)
    # try_compile whole-project signature (3.25+): probe sources are
    # written into the binary dir as a tiny project, then built with the
    # same generator, toolchain, and compiler as the real build.
    set(cxx_modules_probe_dir
        "${CMAKE_CURRENT_BINARY_DIR}/cxx_modules_probe")
    file(
        WRITE "${cxx_modules_probe_dir}/CMakeLists.txt"
        [[
cmake_minimum_required(VERSION 3.28)
project(cxx_modules_probe LANGUAGES CXX)

add_executable(probe main.cpp)
target_compile_features(probe PRIVATE cxx_std_23)
set_target_properties(probe PROPERTIES CXX_EXTENSIONS OFF
                                       CXX_SCAN_FOR_MODULES ON)
target_sources(probe PRIVATE FILE_SET CXX_MODULES FILES probe.cppm)
]])
    file(
        WRITE "${cxx_modules_probe_dir}/probe.cppm"
        [[
export module cxx_modules_probe;

export int probe()
{
    return 0;
}
]])
    file(
        WRITE "${cxx_modules_probe_dir}/main.cpp"
        [[
import cxx_modules_probe;

int main()
{
    return probe();
}
]])
    try_compile(
        cxx_modules_supported
        SOURCES_TYPE PROJECT
        SOURCE_DIR "${cxx_modules_probe_dir}"
        PROJECT cxx_modules_probe
        TARGET probe
        LOG_DESCRIPTION "compiling a minimal C++20 module")
    set(cxx_modules_supported
        "${cxx_modules_supported}"
        CACHE INTERNAL "toolchain builds C++20 named modules")
endif()

if(cxx_modules_supported)
    message(CHECK_PASS "supported")
else()
    message(CHECK_FAIL "unsupported - skipping 06_modules")
    return()
endif()

add_executable(06_modules)

# Scanning is off project-wide (root CMakeLists); this target opts in.
set_target_properties(06_modules PROPERTIES CXX_SCAN_FOR_MODULES ON)

# The file set, not the extension, marks a unit as a module interface.
# The implementation unit stays plain .cpp: some compilers treat
# module-style extensions (.cppm/.ixx) as interface units.
target_sources(
    06_modules
    PRIVATE main.cpp cxx_project.impl.cpp
    PRIVATE FILE_SET CXX_MODULES
            FILES cxx_project.cppm cxx_project-math.cppm
                  cxx_project.utility.cppm)

target_compile_features(06_modules PRIVATE cxx_std_23)
target_link_libraries(06_modules PRIVATE SDL3::SDL3-static warnings)

install(TARGETS 06_modules RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                 COMPONENT runtime)
