cmake_minimum_required(VERSION 4.4)
project(
    rt_demo
    VERSION 0.1.0
    LANGUAGES CXX)

set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(GNUInstallDirs)

add_executable(rt_demo)
add_executable(rt::demo ALIAS rt_demo)
target_sources(rt_demo PRIVATE src/main.cpp)
target_compile_features(rt_demo PRIVATE cxx_std_23)
set_target_properties(
    rt_demo
    PROPERTIES CXX_EXTENSIONS OFF
               BUILD_RPATH_USE_ORIGIN TRUE
               INSTALL_RPATH [[$ORIGIN/../lib]]
               BUILD_WITH_INSTALL_RPATH FALSE)
target_compile_options(
    rt_demo
    PRIVATE $<$<CXX_COMPILER_ID:Clang,AppleClang>:-Wall;-Wextra;-Wpedantic>
            $<$<CXX_COMPILER_ID:GNU>:-Wall;-Wextra;-Wpedantic>
            $<$<CXX_COMPILER_ID:MSVC>:/W4>)

install(TARGETS rt_demo RUNTIME_DEPENDENCY_SET rt_deps
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(
    RUNTIME_DEPENDENCY_SET
    rt_deps
    PRE_EXCLUDE_REGEXES
    [[ld-linux.*]]
    [[libc\.so.*]]
    [[libm\.so.*]]
    [[libgcc_s.*]]
    [[libpthread.*]]
    [[libdl\.so.*]]
    [[librt\.so.*]]
    POST_EXCLUDE_REGEXES
    [[ld-linux.*]]
    [[libc\.so.*]]
    [[libm\.so.*]]
    [[libgcc_s.*]]
    DIRECTORIES
    ${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}
    ${CMAKE_C_IMPLICIT_LINK_DIRECTORIES}
    DESTINATION
    ${CMAKE_INSTALL_LIBDIR})

set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_VENDOR [[rt_demo]])
set(CPACK_PACKAGE_CONTACT [[me@example.com]])
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY [[minimal runtime-deps demo]])
set(CPACK_GENERATOR [[TGZ;DEB]])
set(CPACK_STRIP_FILES TRUE)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)
include(CPack)
