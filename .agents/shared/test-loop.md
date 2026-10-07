# Test loop (native vs cross)

Native (`dev`, `linux_*`, `windows_msvc_*`):
1. `cmake --preset <preset>`
2. `cmake --build --preset <preset>-<config> -j`
3. `ctest --preset <preset>-<config>`
4. `cmake --build build/<preset> --target format tidy` for quality.

Cross (`android_*`, `windows_llvm_mingw_*`, `web_*`):
- Configure only unless the user asked for a full build.
- No `ctest`. Android tests via `./gradlew connectedCheck`,
  Web tests under Node.js, llvm-mingw has no tests.
- On failure: forbid the failed command, move one step closer to the
  changed surface (preset JSON -> toolchain file -> `CMakeLists.txt`).

Never build Release to "just check". Debug is the test config.
Sanitizer/valgrind presets are Debug-only, no package.
