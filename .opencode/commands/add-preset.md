---
description: Add a new platform preset the right way (presets + toolchain + CI row)
agent: build
---

Add preset for `$ARGUMENTS`.

Constraints (from AGENTS.md):
- Edit `cmake/presets/*.json` only. Never hack platform logic into `CMakeLists.txt` or CI yaml.
- Naming: `<compiler>-<variant>` configure, `<name>-release/debug` build, `<name>-package` CPack, `<name>-full` workflow.
- Every native configure preset needs matching build + test presets. Cross presets disable test.
- `binaryDir` stays `build/<preset>`.
- New matrix entries reuse existing presets only.

Steps:
1. Read `CMakePresets.json` + `cmake/presets/base.json` + closest sibling (e.g. `linux.json` for a new Linux variant).
2. Create configure + build (+ test if native, + package/workflow if needed).
3. If cross: add `toolchainFile` under `cmake/toolchains/` and keep `CMAKE_FIND_ROOT_PATH` reachable.
4. Run `cmake --preset <new-preset>` to validate configure. Report files touched.
