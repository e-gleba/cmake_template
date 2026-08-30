# C++20 named modules demo (issue #5). Toolchain support is probed by
# compiling a minimal module with try_compile: one ground-truth test for
# compiler, dependency scanner, generator, and build tool - no version
# matrix to maintain. Unsupported toolchains skip the target.

message(CHECK_START "Checking for C++20 modules support")

# Cached like every Check* result: clear the CMake cache to re-probe
# after a toolchain change.
if(NOT DEFINED cxx_modules_supported)
    set(cxx_modules_probe_dir
        "${CMAKE_CURRENT_BINARY_DIR}/cxx_modules_probe")
    file(
        WRITE "${cxx_modules_probe_dir}/CMakeLists.txt"
        [[
cmake_minimum_required(VERSION 4.4)
project(cxx_modules_probe LANGUAGES CXX)

add_library(cxx_modules_probe STATIC)
target_compile_features(cxx_modules_probe PRIVATE cxx_std_23)
set_target_properties(cxx_modules_probe PROPERTIES CXX_SCAN_FOR_MODULES ON)
target_sources(cxx_modules_probe PRIVATE FILE_SET CXX_MODULES FILES probe.cppm)
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
    try_compile(
        cxx_modules_supported
        SOURCE_DIR "${cxx_modules_probe_dir}"
        PROJECT cxx_modules_probe
        TARGET cxx_modules_probe
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
