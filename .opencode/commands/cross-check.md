---
description: Verify cross presets without building everything (Android, llvm-mingw, Emscripten)
agent: build
---

Cross check for `$ARGUMENTS` (one of: android, mingw, web, all).

Rules:
- Edit `cmake/presets/*.json` only. `dev` stays zero-pin native.
- Cross disables test. Workflow skips test step — never force `ctest` on a cross preset.
- Android: NDK + `c++_shared` + API 24, tidy cleared. Tests via `./gradlew connectedCheck` in `android_project/`, not CTest.
- llvm-mingw: `cmake/toolchains/llvm_mingw.cmake`, `CMAKE_SYSTEM_PROCESSOR` x86_64/i686/aarch64, `--sysroot` + lld baked in.
- Web: emsdk toolchain, wasm32 only, tests under Node.js.

Steps:
1. `cmake --preset <configure-preset>` for each requested platform (dry configure only unless user asked for build).
2. Report per-preset: OK / FAILED + first error line. Never build Release unless asked.
