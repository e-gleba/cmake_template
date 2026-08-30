# Module interface units in CXX_MODULES file sets are always scanned. Keep
# scanning disabled for ordinary C++ sources project-wide.
message(CHECK_START "Checking C++23 named modules")

try_compile(
    cxx_modules_supported
    SOURCES_TYPE CXX_MODULE
    SOURCE_FROM_CONTENT cxx_modules_probe.cppm [[
export module cxx_modules_probe;
export constexpr int module_value = 42;
]]
    SOURCES_TYPE NORMAL
    SOURCE_FROM_CONTENT main.cpp [[
import cxx_modules_probe;
int main()
{
    static_assert(module_value == 42);
}
]]
    CXX_STANDARD 23
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
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
