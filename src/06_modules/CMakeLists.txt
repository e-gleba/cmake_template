# Module interface units in CXX_MODULES file sets are always scanned. Keep
# scanning disabled for ordinary C++ sources project-wide.
message(CHECK_START "Checking C++23 named modules")

# The generated source-file try_compile project assigns its CXX_MODULES
# file set the caller's source directory as its default base directory.
# Generate a complete probe project so its file-set base is self-contained.
set(cxx_modules_probe_source_dir
    "${CMAKE_CURRENT_BINARY_DIR}/cxx_modules_probe")
file(
    WRITE "${cxx_modules_probe_source_dir}/CMakeLists.txt"
    [[
cmake_minimum_required(VERSION 4.4)
project(cxx_modules_probe LANGUAGES CXX)

add_executable(cxx_modules_probe main.cpp)
target_sources(
    cxx_modules_probe
    PRIVATE
        FILE_SET CXX_MODULES
        FILES cxx_modules_probe.cppm)
target_compile_features(cxx_modules_probe PRIVATE cxx_std_23)
set_target_properties(cxx_modules_probe PROPERTIES CXX_EXTENSIONS OFF)
]])
file(
    WRITE "${cxx_modules_probe_source_dir}/cxx_modules_probe.cppm"
    [[
export module cxx_modules_probe;
export constexpr int module_value = 42;
]])
file(
    WRITE "${cxx_modules_probe_source_dir}/main.cpp"
    [[
import cxx_modules_probe;
int main()
{
    static_assert(module_value == 42);
}
]])

try_compile(
    cxx_modules_supported
    PROJECT cxx_modules_probe
    SOURCE_DIR "${cxx_modules_probe_source_dir}"
    TARGET cxx_modules_probe
    LOG_DESCRIPTION "Check whether the active toolchain builds C++23 named modules")

if(cxx_modules_supported)
    message(CHECK_PASS "supported")
else()
    message(CHECK_FAIL "unsupported; skipping 06_modules")
    return()
endif()

add_library(06_modules_library)
add_library(cxx_project::modules ALIAS 06_modules_library)

target_sources(
    06_modules_library
    PRIVATE math.cpp
    PUBLIC
        FILE_SET CXX_MODULES
        FILES math.cppm math-operations.cppm)
target_compile_features(06_modules_library PUBLIC cxx_std_23)
set_target_properties(06_modules_library PROPERTIES CXX_EXTENSIONS OFF)
target_link_libraries(06_modules_library PRIVATE warnings)

add_executable(06_modules main.cpp)
target_compile_features(06_modules PRIVATE cxx_std_23)
set_target_properties(06_modules PROPERTIES CXX_EXTENSIONS OFF)
target_link_libraries(06_modules PRIVATE cxx_project::modules warnings)

install(TARGETS 06_modules RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                 COMPONENT runtime)
