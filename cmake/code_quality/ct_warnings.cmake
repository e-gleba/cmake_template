# --- warnings ----------------------------------------------------------------
# INTERFACE target carrying the project's warning flags.
# Link it PRIVATE into every first-party target - never PUBLIC: consumers
# of an installed package must not inherit our warnings.

# Double inclusion would error on the duplicate add_library - guard it.
include_guard(GLOBAL)

add_library(warnings INTERFACE)

target_compile_options(
    warnings
    INTERFACE
        "$<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang,AppleClang>:-Wall;-Wextra;-Wpedantic;-Wconversion;-Wno-unused-function>"
        "$<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:-Wall;-Wextra;-Wpedantic;-Wconversion;-Wno-unused-function>"
        "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/W4;/wd4100;/wd4505>"
        "$<$<COMPILE_LANG_AND_ID:C,MSVC>:/W4>")

# Let CMake handle -Werror / /WX portably.
set_target_properties(warnings PROPERTIES INTERFACE_COMPILE_WARNING_AS_ERROR ON)

# --- Steam depots: static MinGW runtime, no shipped DLLs -------------------
# Executables must not import libc++.dll / libunwind.dll. LINK_ONLY genex
# applies at link time per target kind: executables link statically, shared
# libraries (SDL3.dll) keep building as DLLs — a bare -static on shared
# links would fail the link. MSVC exes never match (compiler id), and the
# toolchain file stays free of packaging policy.
target_link_options(
    warnings
    INTERFACE
        "$<$<AND:$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>,$<CXX_COMPILER_ID:Clang>,$<C_COMPILER_FRONTEND_VARIANT:GNU>>:LINK_ONLY:-static>")
