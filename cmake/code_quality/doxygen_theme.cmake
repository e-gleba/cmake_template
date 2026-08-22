# --- doxygen-awesome theme ----------------------------------------------------
# Std CMake FetchContent - no CPM, no include-order dependency on
# cmake/cpm.cmake.  Included by ct_doxygen.cmake; exposes
# doxygen-awesome_SOURCE_DIR to the includer (include() shares scope).
#
# The theme repo has no CMakeLists.txt: MakeAvailable only populates it
# and never calls add_subdirectory (documented behavior) - exactly what
# a download-only CSS dependency needs.
#
# No include_guard on purpose: MakeAvailable is idempotent, and a guard
# would stop it re-setting *_SOURCE_DIR in a second includer's scope.

include(FetchContent)
FetchContent_Declare(
    doxygen-awesome
    GIT_REPOSITORY https://github.com/jothepro/doxygen-awesome-css.git
    GIT_TAG v2.4.2
    GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(doxygen-awesome)
