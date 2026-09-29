cmake_minimum_required(VERSION 4.3)

project(
    rt_demo
    VERSION 0.1.0
    LANGUAGES C CXX)

set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

include(GNUInstallDirs)

add_executable(rt_demo main.cpp)
target_compile_features(rt_demo PRIVATE cxx_std_23)
set_target_properties(
    rt_demo PROPERTIES CXX_EXTENSIONS OFF BUILD_RPATH_USE_ORIGIN TRUE
                       INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")

install(
    TARGETS rt_demo
    RUNTIME_DEPENDENCY_SET rt_deps
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(
    RUNTIME_DEPENDENCY_SET rt_deps
    PRE_EXCLUDE_REGEXES [[ld-linux.*]] [[libc\.so.*]] [[libm\.so.*]]
                        [[libpthread.*]] [[libdl\.so.*]] [[librt\.so.*]]
                        [[libresolv\.so.*]]
    POST_EXCLUDE_REGEXES [[ld-linux.*]] [[libc\.so.*]] [[libm\.so.*]]
                         [[libpthread.*]] [[libdl\.so.*]] [[librt\.so.*]]
                         [[libresolv\.so.*]]
    DIRECTORIES ${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES}
                ${CMAKE_C_IMPLICIT_LINK_DIRECTORIES}
    DESTINATION ${CMAKE_INSTALL_LIBDIR})

set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_GENERATOR TGZ)
set(CPACK_STRIP_FILES TRUE)
set(CPACK_VERBATIM_VARIABLES YES)
include(CPack)
