---
description: Configure-check cross presets (android, mingw, web) without building everything
agent: build
---

Cross check for `$ARGUMENTS` (one of `android`, `mingw`, `web`, `all`).
If empty, check `all`.
Configure only. Never `ctest` a cross preset, never build Release unless asked.

Read `.opencode/ai-workflow-adapter.md` and apply its delegation and
text-handling rules. Follow `.agents/shared/ct_test_loop.md` for the
native-vs-cross split.

Preset map (representative configure preset per platform; verify with the
listing below, do not guess variants):
- `android` → `android_clang_aarch64` (NDK, `c++_shared`, API 24, tidy cleared)
- `mingw` → `windows_llvm_mingw_x86_64` (`cmake/toolchains/llvm_mingw.cmake`, auto-downloaded toolchain)
- `web` → `web_emscripten_wasm32` (emsdk toolchain, bootstrapped to `.emsdk/`, wasm32 only)

```text
!`cmake --list-presets 2>/dev/null | grep -E "android|mingw|emscripten|web_"`
```

Steps:
1. `cmake --preset <representative>` per requested platform.
2. Toolchain bootstrap (emsdk/llvm-mingw download) is expected on first run; only errors after bootstrap count as failures.
3. `dev` stays zero-pin native — never "fix" a cross failure by editing shared presets.

Report as a table: preset | OK/FAILED | first error line (failures only).
Android tests run via `./gradlew connectedCheck`, web under Node.js — mention, don't run, unless asked.
