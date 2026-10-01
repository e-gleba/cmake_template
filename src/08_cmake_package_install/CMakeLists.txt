# 08 — relocatable install demo: prints the baked-in build report and ships
# the toolchain runtime (libc++/libunwind) via RUNTIME_DEPENDENCY_SET.
# Builds with the top-level presets only (no local presets); C++20.
include("${CMAKE_CURRENT_LIST_DIR}/tb_build_info.cmake")

# Explicit stdlib choice, never inferred: empty (driver default) or a
# -stdlib= value. The linux_clang preset sets libc++; GCC/MSVC presets
# leave it empty. -stdlib= is a Clang-only flag — setting it for a
# non-Clang compiler fails loudly instead of silently doing the wrong thing.
set(CT_CXX_STDLIB "" CACHE STRING "C++ stdlib for rt_demo (empty = default)")

add_executable(rt_demo)
target_sources(rt_demo PRIVATE main.cpp)

tb_add_build_info(
    TARGET rt_demo
    TEMPLATE "${CMAKE_CURRENT_SOURCE_DIR}/build_info.cpp.in"
    OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")

target_compile_features(rt_demo PRIVATE cxx_std_20)
target_include_directories(rt_demo PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

# fmt is 08-local (root ct_cpm.cmake stays lean): the wrapper makes it
# findable via the CMAKE_PREFIX_PATH the root already exports.
find_package(fmt CONFIG REQUIRED)
# Header-only fmt: templates instantiate in our TUs with our stdlib, so no
# libc++/libstdc++ ABI boundary to manage at link time (fmt's documented
# header-only mode). No extra shared lib lands in the install bundle either.
target_compile_definitions(rt_demo PRIVATE FMT_HEADER_ONLY)
target_link_libraries(rt_demo PRIVATE fmt::fmt warnings)

set_target_properties(
    rt_demo
    PROPERTIES CXX_EXTENSIONS OFF
               CXX_SCAN_FOR_MODULES OFF
               # Relocatable PIE: no fixed load address, ASLR on. Reported as
               # pie/pic/static in the build report via __PIE__/__PIC__.
               POSITION_INDEPENDENT_CODE ON
               BUILD_RPATH_USE_ORIGIN TRUE
               # Build-tree run needs the toolchain runtime (libc++/libunwind
               # live in the compiler's implicit link dirs, not on ld.so path).
               # Compiler-derived, no hardcoded paths.
               BUILD_RPATH "${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}"
               INSTALL_RPATH_USE_LINK_PATH OFF
               # @executable_path on Apple, $ORIGIN elsewhere — one genex,
               # CMP0095 (NEW at our 4.3 floor) escapes $ORIGIN correctly.
               INSTALL_RPATH
               "$<IF:$<PLATFORM_ID:Darwin,iOS>,@executable_path,$ORIGIN>/../${CMAKE_INSTALL_LIBDIR}")

if(CT_CXX_STDLIB)
    target_compile_options(
        rt_demo PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-stdlib=${CT_CXX_STDLIB}>)
    target_link_options(rt_demo PRIVATE -stdlib=${CT_CXX_STDLIB})
endif()

install(
    TARGETS rt_demo
    RUNTIME_DEPENDENCY_SET ct_deps
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    COMPONENT runtime)

install(
    RUNTIME_DEPENDENCY_SET ct_deps
    PRE_EXCLUDE_REGEXES
        [[ld-linux.*]]
        [[libc\.so.*]]
        [[libm\.so.*]]
        [[libpthread.*]]
        [[libdl\.so.*]]
        [[librt\.so.*]]
        [[libresolv\.so.*]]
    POST_EXCLUDE_REGEXES
        [[ld-linux.*]]
        [[libc\.so.*]]
        [[libm\.so.*]]
        [[libpthread.*]]
        [[libdl\.so.*]]
        [[librt\.so.*]]
        [[libresolv\.so.*]]
    DIRECTORIES
        ${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}
        ${CMAKE_C_IMPLICIT_LINK_DIRECTORIES}
    DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    COMPONENT runtime)
