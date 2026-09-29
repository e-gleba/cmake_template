cmake_minimum_required(VERSION 4.3)

project(
    rt_demo
    VERSION 0.1.0
    LANGUAGES C CXX)

include(GNUInstallDirs)

# Linker identity: ask the compiler driver itself which linker it will
# exec (standard -print-prog-name query, no hardcoded paths), then take its
# first --version line. CMAKE_LINKER is not used: CMake's own detection can
# point at a different linker than the driver actually invokes.
set(RT_LINKER "unknown")
set(RT_LINKER_VERSION "unknown")
execute_process(
    COMMAND ${CMAKE_CXX_COMPILER} -print-prog-name=ld
    OUTPUT_VARIABLE RT_LINKER
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE RT_LINKER_QUERY_RESULT
    ERROR_QUIET)
if(RT_LINKER_QUERY_RESULT EQUAL 0 AND NOT RT_LINKER STREQUAL "")
    execute_process(
        COMMAND ${RT_LINKER} --version
        OUTPUT_VARIABLE RT_LINKER_VERSION_RAW
        RESULT_VARIABLE RT_LINKER_RESULT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    if(RT_LINKER_RESULT EQUAL 0)
        string(REGEX MATCH "[^\n]*" RT_LINKER_VERSION
                     "${RT_LINKER_VERSION_RAW}")
    endif()
endif()

# Build metadata header, generated into the binary dir only.
configure_file(rt_build_info.hpp.in
               ${PROJECT_BINARY_DIR}/generated/rt_build_info.hpp @ONLY)

add_executable(rt_demo main.cpp)
target_compile_features(rt_demo PRIVATE cxx_std_23)
target_include_directories(rt_demo PRIVATE ${PROJECT_BINARY_DIR}/generated)
# Imported-lib bundling test: libatomic from the toolchain (found via the
# env-provided LIBRARY_PATH, no hardcoded paths). Linked PRIVATE, so it
# lands in NEEDED and the RUNTIME_DEPENDENCY_SET below must pack it.
find_library(ct_atomic_lib atomic HINTS $ENV{LIBRARY_PATH} REQUIRED)
add_library(ct_atomic UNKNOWN IMPORTED)
set_target_properties(ct_atomic PROPERTIES IMPORTED_LOCATION
                                            "${ct_atomic_lib}")
target_link_libraries(rt_demo PRIVATE ct_atomic)
target_compile_options(
    rt_demo PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-stdlib=libc++>)
target_link_options(rt_demo PRIVATE -stdlib=libc++)
set_target_properties(
    rt_demo PROPERTIES CXX_EXTENSIONS OFF
                       CXX_SCAN_FOR_MODULES OFF
                       BUILD_RPATH_USE_ORIGIN TRUE
                       # Relocatable binary via standard CMake RPATH handling:
                       # $ORIGIN keeps the installed bin/+lib tree movable;
                       # USE_LINK_PATH OFF stops absolute link dirs leaking
                       # into the installed RPATH.
                       INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}"
                       INSTALL_RPATH_USE_LINK_PATH OFF)

install(
    TARGETS rt_demo
    RUNTIME_DEPENDENCY_SET ct_deps
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(
    RUNTIME_DEPENDENCY_SET ct_deps
    # Bundle the toolchain's runtime via standard CMake dependency
    # resolution (install RUNTIME_DEPENDENCY_SET + file(GET_RUNTIME_DEPENDENCIES)):
    # DIRECTORIES extends its search with the compiler's own implicit link
    # dirs (CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES, standard CMake compiler
    # info) plus the env-provided LIBRARY_PATH. Only OS libs are excluded,
    # so whatever the active toolchain needs (libc++/libstdc++/libgcc_s)
    # gets packed with no hardcoded paths.
    PRE_EXCLUDE_REGEXES [[ld-linux.*]] [[libc\.so.*]] [[libm\.so.*]]
                        [[libpthread.*]] [[libdl\.so.*]] [[librt\.so.*]]
                        [[libresolv\.so.*]]
    POST_EXCLUDE_REGEXES [[ld-linux.*]] [[libc\.so.*]] [[libm\.so.*]]
                         [[libpthread.*]] [[libdl\.so.*]] [[librt\.so.*]]
                         [[libresolv\.so.*]]
    DIRECTORIES ${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}
                ${CMAKE_C_IMPLICIT_LINK_DIRECTORIES} $ENV{LIBRARY_PATH}
    DESTINATION ${CMAKE_INSTALL_LIBDIR})

set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_GENERATOR TGZ)
set(CPACK_STRIP_FILES TRUE)
set(CPACK_VERBATIM_VARIABLES YES)
include(CPack)
