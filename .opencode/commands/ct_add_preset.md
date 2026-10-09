---
description: Add a platform preset the right way (presets file, toolchain, validation)
agent: build
---

Add preset for `$ARGUMENTS` (required: compiler + platform + arch, e.g. `linux clang aarch64`).

Read `.opencode/ai-workflow-adapter.md` and apply its delegation and
text-handling rules. Constraints from `.opencode/AGENTS.md` (non-negotiable):

- Edit `cmake/presets/*.json` only. New file → also add it to the
  `CMakePresets.json` `include` list. Never hack platform logic into
  `CMakeLists.txt` or CI yaml.
- Naming: `<compiler>-<variant>` configure, `<name>-release/debug` build,
  `<name>-package` CPack, `<name>-full` workflow. `binaryDir` stays
  `build/<preset>`.
- Every native configure preset needs matching build + test presets.
  Cross presets disable test.
- A new preset does NOT get a CI matrix row: new rows reuse existing
  presets only. Say so explicitly instead of wiring CI.

Steps:
1. If `$ARGUMENTS` lacks compiler, platform, or arch, ask through the
   native question tool — options grounded in `cmake/presets/*.json`
   siblings — then continue. Never guess the triple.
2. Read `cmake/presets/base.json` + the closest sibling preset for the pattern.
3. Create configure + build (+ test if native, + package/workflow if shipping).
4. Cross only: add `toolchainFile` under `cmake/toolchains/`, keep
   `CMAKE_FIND_ROOT_PATH` reachable for `find_package` configs.
5. Validate: `cmake --list-presets` shows it, then `cmake --preset <new-preset>` configures clean.

Report: files touched, preset names created, configure OK/FAILED + first error line.
