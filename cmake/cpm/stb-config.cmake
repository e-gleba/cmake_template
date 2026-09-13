cpmaddpackage(
    NAME
    stb
    GITHUB_REPOSITORY
    nothings/stb
    SYSTEM
    ON
    GIT_SHALLOW
    ON
    GIT_TAG
    master
    DOWNLOAD_ONLY
    YES)

add_library(
    stb
    INTERFACE
    EXCLUDE_FROM_ALL
    ON)

add_library(stb::stb ALIAS stb EXCLUDE_FROM_ALL ON)

target_include_directories(stb SYSTEM INTERFACE $<BUILD_INTERFACE:${stb_SOURCE_DIR}>)
