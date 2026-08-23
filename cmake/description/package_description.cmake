# ─── Package Description ───────────────────────────────────────────
# Sets CPack metadata and platform-specific packaging variables.
# Loaded from the root CMakeLists.txt via include(package_description).
#
# Everything derivable comes from the root project() call
# (PROJECT_NAME, PROJECT_VERSION, PROJECT_DESCRIPTION,
# PROJECT_HOMEPAGE_URL) — edit project() once and every package,
# desktop entry, and generated file follows. Only the fields project()
# has no slot for (vendor, contact, license) are kept here.
#
# CMAKE_CURRENT_LIST_DIR = directory containing THIS file
#                          (cmake/description/)
# PROJECT_SOURCE_DIR     = root of the calling project
#
# Never use CMAKE_SOURCE_DIR — it breaks when this project is
# consumed as a subdirectory of a larger build.
# Ref: Professional CMake §8.3 "Project-relative Variables"
# ───────────────────────────────────────────────────────────────────

# ─── Project metadata (no project() slot for these) ───────────────
set(PROJECT_VENDOR "e-gleba")
set(PROJECT_CONTACT "i@egleba.ru")
set(PROJECT_LICENSE "MIT") # SPDX identifier
set(PROJECT_GROUP "System")

# ─── Resource files ────────────────────────────────────────────────
set(PROJECT_ICON_FILE "${CMAKE_CURRENT_LIST_DIR}/icon.png")
set(PROJECT_LICENSE_FILE "${PROJECT_SOURCE_DIR}/license.md")
set(PROJECT_README_FILE "${PROJECT_SOURCE_DIR}/readme.md")

# ─── CPack core configuration ─────────────────────────────────────
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VENDOR "${PROJECT_VENDOR}")
set(CPACK_PACKAGE_CONTACT "${PROJECT_CONTACT}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_HOMEPAGE_URL "${PROJECT_HOMEPAGE_URL}")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "${CPACK_PACKAGE_NAME}"
)# avoid version in install path
set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_LICENSE_FILE}")
set(CPACK_RESOURCE_FILE_README "${PROJECT_README_FILE}")
set(CPACK_VERBATIM_VARIABLES YES) # always set, prevents escaping bugs

# ─── Long description ──────────────────────────────────────────────
# Generated from the root project() metadata — no hand-maintained text
# file to drift out of sync with the project. file(GENERATE) writes
# into the build tree and only when the content changes, so the source
# tree stays clean and re-configures stay cheap.
set(CPACK_PACKAGE_DESCRIPTION_FILE
    "${PROJECT_BINARY_DIR}/package_description.txt")
file(
    GENERATE
    OUTPUT "${CPACK_PACKAGE_DESCRIPTION_FILE}"
    CONTENT
        "${PROJECT_DESCRIPTION}

Version:  ${PROJECT_VERSION}
Homepage: ${PROJECT_HOMEPAGE_URL}
Vendor:   ${PROJECT_VENDOR}
Contact:  ${PROJECT_CONTACT}
License:  ${PROJECT_LICENSE}
")

# ─── CPack icon ────────────────────────────────────────────────────
if(EXISTS "${PROJECT_ICON_FILE}")
    set(CPACK_PACKAGE_ICON "${PROJECT_ICON_FILE}")
endif()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Generator-specific settings
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ─── DEB ───────────────────────────────────────────────────────────
set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")

# ─── RPM ───────────────────────────────────────────────────────────
set(CPACK_RPM_PACKAGE_DESCRIPTION "${CPACK_PACKAGE_DESCRIPTION_SUMMARY}")
set(CPACK_RPM_PACKAGE_GROUP "${PROJECT_GROUP}")
set(CPACK_RPM_PACKAGE_LICENSE "${PROJECT_LICENSE}")
set(CPACK_RPM_PACKAGE_AUTOREQPROV "yes")

# ─── Windows (NSIS) ───────────────────────────────────────────────
set(CPACK_NSIS_MODIFY_PATH ON)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Platform-specific install rules (Linux freedesktop integration)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    include(GNUInstallDirs)

    # ── .desktop file ──────────────────────────────────────
    block(SCOPE_FOR VARIABLES)
    set(desktop_in "${CMAKE_CURRENT_LIST_DIR}/package.desktop.in")
    if(EXISTS "${desktop_in}")
        configure_file(
            "${desktop_in}"
            "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.desktop" @ONLY)
        install(
            FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.desktop"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications"
            COMPONENT runtime)
    endif()
    endblock()

    # ── Application icon ───────────────────────────────────
    if(EXISTS "${PROJECT_ICON_FILE}")
        install(
            FILES "${PROJECT_ICON_FILE}"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/pixmaps"
            RENAME "${PROJECT_NAME}.png"
            COMPONENT runtime)
        install(
            FILES "${PROJECT_ICON_FILE}"
            DESTINATION
                "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/256x256/apps"
            RENAME "${PROJECT_NAME}.png"
            COMPONENT runtime)
    endif()
endif()
