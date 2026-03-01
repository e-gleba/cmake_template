cmake_minimum_required(VERSION 3.28)

project(
    cxx_project
    VERSION 1.0.0
    DESCRIPTION "My awesome C/C++ project!"
    HOMEPAGE_URL "https://github.com/e-gleba/template-cpp-project"
    LANGUAGES C CXX)

list(
    APPEND
    CMAKE_PREFIX_PATH
    "${CMAKE_CURRENT_LIST_DIR}/cmake"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/description"
    "${CMAKE_CURRENT_LIST_DIR}/cmake/code_quality")

if(CMAKE_CROSSCOMPILING)
    list(
        APPEND
        CMAKE_FIND_ROOT_PATH
        "${CMAKE_CURRENT_LIST_DIR}/cmake"
        "${CMAKE_CURRENT_LIST_DIR}/cmake/description"
        "${CMAKE_CURRENT_LIST_DIR}/cmake/code_quality")
endif()

find_package(warnings CONFIG REQUIRED)
find_package(package_description CONFIG REQUIRED)

find_package(clang_format CONFIG REQUIRED)
find_package(clang_tidy CONFIG REQUIRED)
find_package(clang_doc CONFIG REQUIRED)
find_package(cpplint CONFIG REQUIRED)
find_package(doxygen CONFIG REQUIRED)

find_package(cpm CONFIG REQUIRED)

set(CPACK_SYSTEM_NAME "${CPACK_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")

install(FILES "${CPACK_RESOURCE_FILE_LICENSE}" "${CPACK_RESOURCE_FILE_README}"
        DESTINATION . COMPONENT documentation)

add_subdirectory(src)

include(CTest)
if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

include(CPack)
