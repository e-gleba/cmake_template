cpmaddpackage(
    NAME
    fmt
    GITHUB_REPOSITORY
    fmtlib/fmt
    GIT_TAG
    12.2.0
    GIT_SHALLOW
    ON
    GIT_PROGRESS
    ON
    EXCLUDE_FROM_ALL
    YES
    SYSTEM
    YES
    OPTIONS
    "FMT_DOC OFF"
    "FMT_TEST OFF"
    "FMT_INSTALL OFF")

# fmt's own sources are not warning-clean under our tidy/warning set —
# same treatment as SDL3 in sdl3-config.cmake.
if(TARGET fmt)
    set_target_properties(
        fmt PROPERTIES C_CLANG_TIDY ""
                       CXX_CLANG_TIDY ""
                       C_CPPCHECK ""
                       CXX_CPPCHECK ""
                       COMPILE_WARNING_AS_ERROR OFF
                       EXCLUDE_FROM_ALL TRUE)
    target_compile_options(
        fmt PRIVATE $<$<CXX_COMPILER_FRONTEND_VARIANT:MSVC>:/W0>
                    $<$<NOT:$<CXX_COMPILER_FRONTEND_VARIANT:MSVC>>:-w>)
endif()
