# C++20 named modules demo (issue #5). Toolchain support is probed by
# compiling a minimal module with try_compile: one ground-truth test for
# compiler, dependency scanner, generator, and build tool - no version
# matrix to maintain. Unsupported toolchains skip the target.
#
# Requirements: Ninja 1.11+ or VS 2022 17.4+ generator, MSVC 14.34 /
# Clang 16 (with clang-scan-deps next to the compiler) / GCC 14.
# Header units are unsupported by CMake; import std is still experimental
# (CMAKE_EXPERIMENTAL_CXX_IMPORT_STD, Ninja only). The private module
# fragment unit must be the only unit of its module (module.private.frag)
# - hence the second module below.

message(CHECK_START "Checking for C++20 modules support")

# Cached like every Check* result: clear the CMake cache to re-probe
# after a toolchain change.
if(NOT DEFINED cxx_modules_supported)
    # SOURCES_FROM_CONTENT (CMake 3.25+): probe sources live in bracket
    # arguments, nothing written to disk. The SOURCE_DIR/PROJECT signature
    # needs CMake 4.2, above the project floor of 3.28.
    try_compile(
        cxx_modules_supported
        SOURCES_FROM_CONTENT probe.cppm
                             [[
export module cxx_modules_probe;

export int probe()
{
    return 0;
}
]]
        SOURCES_FROM_CONTENT main.cpp
                             [[
import cxx_modules_probe;

int main()
{
    return probe();
}
]]
        CMAKE_FLAGS "-DCMAKE_CXX_STANDARD=23"
                    "-DCMAKE_CXX_STANDARD_REQUIRED=ON"
                    "-DCMAKE_CXX_EXTENSIONS=OFF"
                    "-DCMAKE_CXX_SCAN_FOR_MODULES=ON"
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
