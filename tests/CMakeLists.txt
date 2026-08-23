# Explicit source list — no file(GLOB): the build must notice a new file.
# The Android JNI bridge is pulled in by a generator expression, so it
# compiles only for Android instead of being marked HEADER_FILE_ONLY
# everywhere else.
if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    add_library(tests SHARED)
else()
    add_executable(tests)
endif()

target_sources(
    tests PRIVATE main.cpp doctest_example.cpp
                  $<$<PLATFORM_ID:Android>:doctest_android_jni.cpp>)

target_include_directories(tests PRIVATE "${CMAKE_CURRENT_LIST_DIR}")
target_compile_features(tests PRIVATE cxx_std_23)

target_link_libraries(tests PRIVATE doctest::doctest
                                    $<$<PLATFORM_ID:Android>:log>)

target_compile_definitions(
    tests
    PRIVATE DOCTEST_CONFIG_NO_SHORT_MACRO_NAMES
            DOCTEST_CONFIG_INCLUDE_TYPE_TRAITS
            DOCTEST_CONFIG_REQUIRE_STRINGIFICATION_FOR_ALL_USED_TYPES
            DOCTEST_CONFIG_ASSERTS_RETURN_VALUES
            DOCTEST_CONFIG_USE_STD_HEADERS)

# doctest_discover_tests runs the built executable with --list-
# test-cases to register each test case individually with CTest.
# This only works on native builds where the host can execute the
# binary. When cross-compiling, the executable targets a foreign
# platform and cannot run on the host.
if(NOT CMAKE_CROSSCOMPILING)
    include(doctest)
    doctest_discover_tests(tests)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    # Discovery needs a host-runnable binary (see above), but the suite
    # runs fine under Node.js — the Emscripten toolchain sets
    # CMAKE_CROSSCOMPILING_EMULATOR to node when found, and ctest
    # prepends it to the test command automatically.
    add_test(NAME tests COMMAND tests)
endif()

# emcc disables C++ exception catching by default; doctest needs it.
target_compile_options(tests PRIVATE $<$<PLATFORM_ID:Emscripten>:-fexceptions>)
target_link_options(tests PRIVATE $<$<PLATFORM_ID:Emscripten>:-fexceptions>)
