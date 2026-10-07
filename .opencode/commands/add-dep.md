---
description: Add a CPM dependency with pinned tag and find_package config
agent: build
---

Add dependency `$ARGUMENTS`.

Rules (from AGENTS.md):
- CPM primary, vcpkg manifest optional overlay. Tagged releases, not branches.
- `FETCHCONTENT_QUIET OFF` for CI.
- Options inside `CPMAddPackage`.
- `find_package(CONFIG REQUIRED)` via `cmake/cpm/` configs. Keep cross reachable via `CMAKE_FIND_ROOT_PATH`.
- Borrowed code links itself: Origin URL + version + license.

Steps:
1. Read `cmake/ct_cpm.cmake` + `cmake/cpm/*-config.cmake` for the pattern.
2. Add `CPMAddPackage` with pinned tag + options, wire `target_link_libraries` (`PRIVATE` unless propagation needed).
3. Configure `cmake --preset dev` to verify. Report: package, version, target, link scope.
