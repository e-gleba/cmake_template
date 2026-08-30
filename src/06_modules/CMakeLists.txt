# C++20 named modules demo (issue #5). Nothing to enable: the probe
# below decides, and unsupported setups skip the target cleanly.
# Guard-then-build pattern mirrors src/05_webassembly.

message(CHECK_START "Checking for C++20 modules support")

set(modules_ok TRUE)
set(modules_why "")

macro(deny_modules reason)
    set(modules_ok FALSE)
    set(modules_why "${reason}")
endmacro()

# Only these generators can scan module dependencies.
if(NOT CMAKE_GENERATOR MATCHES "^Ninja"
   AND NOT CMAKE_GENERATOR MATCHES "^Visual Studio")
    deny_modules("generator '${CMAKE_GENERATOR}' cannot scan modules")
endif()

# Cross builds (android, emscripten, llvm-mingw) are out of scope here.
if(modules_ok AND CMAKE_CROSSCOMPILING)
    deny_modules("cross-compiling")
endif()

# Compilers CMake 4.4 can drive: MSVC 14.34+, Clang 16+, GCC 14+.
if(modules_ok)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND MSVC_VERSION VERSION_LESS 1934)
        deny_modules("MSVC ${MSVC_VERSION} < 19.34 (VS 2022 17.4)")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 16)
        deny_modules("Clang ${CMAKE_CXX_COMPILER_VERSION} < 16")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 14)
        deny_modules("GCC ${CMAKE_CXX_COMPILER_VERSION} < 14")
    elseif(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(MSVC|Clang|GNU)$")
        deny_modules("compiler '${CMAKE_CXX_COMPILER_ID}' unsupported")
    endif()
endif()

# Clang also needs its dependency scanner next to the compiler.
if(modules_ok AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    get_filename_component(clang_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
    string(REGEX MATCH "^[0-9]+" clang_major "${CMAKE_CXX_COMPILER_VERSION}")
    find_program(
        clang_scan_deps
        NAMES clang-scan-deps-${clang_major} clang-scan-deps
        HINTS "${clang_dir}")
    if(NOT clang_scan_deps)
        deny_modules("clang-scan-deps not found (apt install clang-tools)")
    endif()
endif()

# Ninja must speak dyndep 1.0 (1.11+).
if(modules_ok AND CMAKE_GENERATOR MATCHES "^Ninja")
    execute_process(
        COMMAND "${CMAKE_MAKE_PROGRAM}" --version
        OUTPUT_VARIABLE ninja_version
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(ninja_version VERSION_LESS 1.11)
        deny_modules("Ninja ${ninja_version} < 1.11")
    endif()
endif()

# The demo window links the SDL3 the project already fetches.
if(modules_ok AND NOT TARGET SDL3::SDL3-static)
    deny_modules("SDL3::SDL3-static target missing")
endif()

if(NOT modules_ok)
    message(CHECK_FAIL "${modules_why} - skipping 06_modules")
    return()
endif()
message(CHECK_PASS "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")

add_executable(06_modules)

# Scanning is off project-wide (root CMakeLists); this target opts in.
set_target_properties(06_modules PROPERTIES CXX_SCAN_FOR_MODULES ON)

# Plain sources: the module implementation unit and the consumer. Keep
# module-style extensions (.cppm/.ixx) off implementation units - some
# compilers treat them as interface units, which breaks the build.
target_sources(06_modules PRIVATE main.cpp cxx_project.impl.cpp)

# Module-providing sources must live in a FILE_SET of type CXX_MODULES:
# the file set, not the extension, marks a unit as a module interface.
target_sources(
    06_modules
    PRIVATE FILE_SET CXX_MODULES
            FILES cxx_project.cppm cxx_project-math.cppm
                  cxx_project.utility.cppm)

target_compile_features(06_modules PRIVATE cxx_std_23)
target_link_libraries(06_modules PRIVATE SDL3::SDL3-static warnings)

install(TARGETS 06_modules RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                 COMPONENT runtime)
