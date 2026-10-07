# CI entry points as build targets.
#
# Workflows name only a preset and one of these targets — no build-tree
# paths, executable names, or config names leak into .github/. Rename a
# target or move an output and only this file changes.
#
# Short ci_* names (not ${PROJECT_NAME}_*) are a stable contract:
# renaming project() must not touch workflows. Every target probes with
# if(TARGET ...) at include time, so unrelated configures stay clean —
# include this module after src/ and tests/.
#
# DEPENDS is always explicit: genex cross-target references do not order
# custom targets reliably on all generators.
#
# Requires CMake 4.3+: $<TARGET_FILE_*>, WORKING_DIRECTORY generator
# expressions, cmake -E copy/tar.

include_guard(GLOBAL)

# --- docs -----------------------------------------------------------------
if(TARGET docs)
    add_custom_target(
        ci_docs
        DEPENDS docs
        COMMAND "${CMAKE_COMMAND}" -DBUILD_DIR=${PROJECT_BINARY_DIR}
                -P "${CMAKE_CURRENT_LIST_DIR}/scripts/verify_docs.cmake"
        VERBATIM
        COMMENT "verifying Doxygen HTML entry point")
endif()

# --- web bundle -------------------------------------------------------------
if(TARGET 05_webassembly)
    # Legacy release-asset name, kept byte-stable; defined once, here.
    set(ct_ci_web_archive "cxx_project-Web_Emscripten_wasm32.zip")
    add_custom_target(
        ci_web
        DEPENDS 05_webassembly
        COMMAND "${CMAKE_COMMAND}" -E tar cf
                "${PROJECT_BINARY_DIR}/${ct_ci_web_archive}" --format=zip --
                "$<TARGET_FILE_NAME:05_webassembly>"
                "$<TARGET_FILE_BASE_NAME:05_webassembly>.js"
                "$<TARGET_FILE_BASE_NAME:05_webassembly>.wasm"
        WORKING_DIRECTORY "$<TARGET_FILE_DIR:05_webassembly>"
        VERBATIM
        COMMENT "bundling WebAssembly application")
endif()
