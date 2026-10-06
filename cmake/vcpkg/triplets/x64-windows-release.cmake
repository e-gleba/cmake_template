# Release-only overlay triplet for the vcpkg lane: halves cold dependency
# builds by skipping debug variants. Debug builds through the vcpkg
# presets are unsupported with this triplet (no debug libs installed).
# CRT stays dynamic to match the default x64-windows triplet; only the
# build type changes.
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_BUILD_TYPE release)
