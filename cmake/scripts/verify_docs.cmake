# Fails unless the Doxygen HTML entry point exists.
#
#   cmake -DBUILD_DIR=build/linux_clang_x86_64 \
#       -P cmake/scripts/verify_docs.cmake

if(NOT DEFINED BUILD_DIR OR BUILD_DIR STREQUAL "")
    message(FATAL_ERROR "BUILD_DIR is required")
endif()

set(docs_index "${BUILD_DIR}/generated_docs/html/index.html")

if(NOT EXISTS "${docs_index}")
    message(FATAL_ERROR "documentation index not found at ${docs_index}")
endif()

message(STATUS "documentation index found at ${docs_index}")
