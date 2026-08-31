# ─── SteamPipe deploy scripts ───────────────────────────────────────
# Generates the SteamPipe build scripts (app/depot VDF) and
# steam_appid.txt from the .in templates next to this file into
# ${PROJECT_BINARY_DIR}/steam/. Enabled per preset via CT_STEAMPIPE=ON
# (see cmake/presets/steam.json).
#
# Everything derivable comes from the root project() call — the VDF
# "desc" tracks PROJECT_VERSION on every configure. Only the Steam IDs
# are cache variables; the defaults are Valve's Spacewar test app.
# Override for a real game on the command line or in a preset:
#   -DCT_STEAM_APP_ID=123456 -DCT_STEAM_DEPOT_ID_WINDOWS=123457 ...
#
# The app manifest's depot keys and each depot script's DepotID come
# from the SAME variable — the two cannot drift apart.
# ───────────────────────────────────────────────────────────────────

option(CT_STEAMPIPE "Generate SteamPipe deploy scripts" OFF)
if(NOT CT_STEAMPIPE)
    return()
endif()

# 480 = Spacewar, Valve's test app; 4801/4802 are placeholder depot IDs.
set(CT_STEAM_APP_ID
    "480"
    CACHE STRING "Steam App ID")
set(CT_STEAM_DEPOT_ID_WINDOWS
    "4801"
    CACHE STRING "Depot ID for the Windows x86_64 depot")
set(CT_STEAM_DEPOT_ID_LINUX
    "4802"
    CACHE STRING "Depot ID for the Linux x86_64 depot")

set(ct_steampipe_templates
    app_build.vdf
    depot_linux_x86_64.vdf
    depot_windows_x86_64.vdf
    steam_appid.txt)
foreach(template IN LISTS ct_steampipe_templates)
    configure_file(
        "${CMAKE_CURRENT_LIST_DIR}/${template}.in"
        "${PROJECT_BINARY_DIR}/steam/${template}"
        @ONLY)
endforeach()

message(STATUS "SteamPipe scripts: ${PROJECT_BINARY_DIR}/steam")
