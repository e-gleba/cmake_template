cpmaddpackage(
    NAME
    implot
    VERSION
    1.0
    GITHUB_REPOSITORY
    epezent/implot
    SYSTEM
    ON
    EXCLUDE_FROM_ALL
    ON
    GIT_SHALLOW
    ON
    DOWNLOAD_ONLY
    TRUE)

add_library(implot STATIC)

target_sources(
    implot
    PRIVATE ${implot_SOURCE_DIR}/implot.cpp
            ${implot_SOURCE_DIR}/implot_items.cpp
            ${implot_SOURCE_DIR}/implot_demo.cpp # optional demo
)

target_include_directories(implot SYSTEM PUBLIC $<BUILD_INTERFACE:${implot_SOURCE_DIR}>)

target_link_libraries(implot PRIVATE imgui)

set_target_properties(
    implot
    PROPERTIES C_CLANG_TIDY ""
               CXX_CLANG_TIDY ""
               C_CPPCHECK ""
               CXX_CPPCHECK ""
               COMPILE_WARNING_AS_ERROR OFF
               EXCLUDE_FROM_ALL TRUE)

target_compile_options(
    implot
    PRIVATE $<$<CXX_COMPILER_FRONTEND_VARIANT:MSVC>:/W0>
            $<$<NOT:$<CXX_COMPILER_FRONTEND_VARIANT:MSVC>>:-w>)
