# Dependency bootstrap: fetch CPM itself, then resolve the project's
# packages through the config files in cmake/cpm/ (each wraps CPMAddPackage).
# Loaded once from the root CMakeLists.txt via include(cpm).

include(FetchContent)

# NOTE: no URL_HASH on purpose. Renovate bumps ct_cpm_version but cannot
# recompute a hash — a stale hash fails the configure step harder than
# no hash. Same trust model as the GIT_TAG-pinned deps below.
set(ct_cpm_version "0.43.2")

fetchcontent_declare(
    get_cpm
    URL "https://github.com/cpm-cmake/CPM.cmake/releases/download/v${ct_cpm_version}/CPM.cmake"
    DOWNLOAD_NO_EXTRACT TRUE)

fetchcontent_makeavailable(get_cpm)

include("${get_cpm_SOURCE_DIR}/CPM.cmake")

# Local package reuse (vcpkg manifest, system, etc.) stays OFF by default:
# cmake/cpm/ wrappers share the real packages' config names, so ON makes
# find_package() hit the wrapper again -> infinite recursion (verified).
# vcpkg users opt in with -DCPM_USE_LOCAL_PACKAGES=ON alongside the vcpkg
# toolchain, where vcpkg paths precede the wrappers in CMAKE_PREFIX_PATH.
# Ref: https://github.com/cpm-cmake/CPM.cmake#find_package-integration
if(NOT DEFINED CPM_USE_LOCAL_PACKAGES)
    set(CPM_USE_LOCAL_PACKAGES OFF)
endif()

# Keep clang-tidy out of the dependency source cache. Guarded: the cache
# dir only exists when CPM_SOURCE_CACHE is set (CI always sets it).
if(CPM_SOURCE_CACHE)
    file(WRITE "${CPM_SOURCE_CACHE}/.clang-tidy" "Checks: '-*'\n")
endif()

set(ct_cpm_deps_dir "${CMAKE_CURRENT_LIST_DIR}/cpm")

list(APPEND CMAKE_PREFIX_PATH "${ct_cpm_deps_dir}")
if(CMAKE_CROSSCOMPILING)
    # Toolchains may scope find_package() to CMAKE_FIND_ROOT_PATH
    # (CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY) — keep our configs reachable.
    list(APPEND CMAKE_FIND_ROOT_PATH "${ct_cpm_deps_dir}")
endif()

find_package(doctest CONFIG REQUIRED)
find_package(sdl3 CONFIG REQUIRED)
find_package(gsl CONFIG REQUIRED)
find_package(imgui CONFIG REQUIRED)
