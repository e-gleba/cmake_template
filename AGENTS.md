# cmake_template

C++23. C+CXX. CMake 4.3+. Ninja Multi-Config. CPM. doctest + CTest.
Think first. Minimal diff. Verify with build + tests.

## Build

cmake --preset dev && cmake --build --preset dev -j && ctest --preset dev
ln -sf build/dev/compile_commands.json .

## Layout

- CMakeLists.txt — project(), CT_* cache vars, add_subdirectory(src), top-level only tests + packaging + CPack last
- CMakePresets.json — includes cmake/presets/*.json
- cmake/presets/ — base.json dev + build_release/debug + test_base, linux.json, windows.json, android.json, web.json, steam.json
- cmake/toolchains/ — llvm_mingw.cmake, emscripten.cmake
- cmake/ct_cpm.cmake — fetch CPM, find_package(doctest, sdl3, gsl, imgui)
- cmake/cpm/ — package configs
- cmake/cpack/ct_cpack.cmake — DEB/RPM/NSIS metadata, CPACK_SYSTEM_NAME os_compiler_arch
- cmake/code_quality/ + cmake/scripts/ + cmake/steampipe/
- src/ — 01_hello_world 02_sdl3_app 03_unity_build 04_tracy_profiler 05_webassembly 06_modules, one CMakeLists per dir
- tests/ — doctest_example.cpp, main.cpp, doctest_android_jni.cpp
- tools/ + scripts/ — python helpers, format/lint scripts
- docker/ — official-base images, no source COPY
- android_project/ — manifest + Gradle wrapper
- nix/ — nix shells
- docs/references.md — links live here, not readme

## CMake

- Targets only. No CMAKE_CXX_FLAGS, include_directories, link_libraries, add_definitions.
- No file(GLOB). Explicit sources. No CMAKE_BUILD_TYPE in project. Preset owns it + CMAKE_CONFIGURATION_TYPES.
- CT_* user cache vars/options, ct_* targets/functions/locals. Upstream names untouched.
- PUBLIC propagates, PRIVATE not, INTERFACE consumers-only.
- Alias every exported lib. Warnings per-compiler guarded, never PUBLIC.
- CMAKE_CXX_SCAN_FOR_MODULES OFF unless modules used. CXX_EXTENSIONS OFF.
- Generated files in binary dir only. Multiline in [[...]], never \n escapes.
- PROJECT_IS_TOP_LEVEL gates tests/packaging. PROJECT_SOURCE_DIR, never CMAKE_SOURCE_DIR in modules.
- Static runtime: MSVC frontend -> MSVC_RUNTIME_LIBRARY MT, GNU-like frontend -> $<$<NOT:$<CXX_COMPILER_FRONTEND_VARIANT:MSVC>>:-static-libstdc++;-static-libgcc>, full -static Windows exe only.

## C++

- C++23. Value types copy/move, share nothing.
- snake_case types/funcs/vars. UPPER_CASE macros only. No m_, no Hungarian.
- {} over (). Init every var. RAII only, no new/delete.
- class for invariants, struct for data. final on non-base. Rule of zero. No owning raw ptrs.
- std::int32_t/uint32_t/int64_t/uint64_t with std::. size_t sizes, ptrdiff_t diffs.
- span/string_view by value, never stored. [[nodiscard]]. expected<T,E> for fallible, no magic values.
- gsl::Expects/Ensures for contracts. const default, constexpr free, noexcept honest.
- New type only if reused twice. No single-use abstraction.
- Borrowed code links itself: Origin URL + version + license. No link, no borrow.

## Python tools/

- stdlib first: pathlib, dataclasses, subprocess, concurrent.futures, sqlite3.
- black . && ruff check --fix . Both in CI + pre-commit.
- Type hints public funcs. dict[str,str], not Dict. pathlib.Path, not strings. with for resources.
- f-strings. logging, no print in libs. pytest, one behaviour per test.
- New dep only with stars + recent commit + cause. Never one-facility dep.

## Presets

- Edit cmake/presets/*.json only. dev = zero-pin native iteration. Platform presets pin compilers.
- Native needs build + test (+package/workflow). Cross disables test, workflow skips test step.
- linux_clang_x86_64 / linux_gcc_x86_64 + release/debug + TGZ/DEB.
- windows_msvc_x86_64 (VS17) + windows_llvm_mingw_x86/x86_64/aarch64, cross has no test presets.
- android_clang_aarch64/armv7/x86_64/x86, NDK + c++_shared + API24, tidy cleared, release (+debug aarch64/x86_64).
- web_emscripten_wasm32 via Emscripten toolchainFile, Node tests.
- steam: linux_steamrt4_x86_64 + windows_msvc_steam_x86_64 + windows_llvm_mingw_steam_x86_64, CT_STEAMPIPE ON, IPO ON.
- No platform hacks in CI. Logic in presets/docker/toolchains.

## Deps

- CPM only. Tagged releases, not branches. FETCHCONTENT_QUIET OFF for CI.
- Options inside CPMAddPackage. No conan/vcpkg.json.
- find_package(CONFIG REQUIRED) via cmake/cpm configs. Cross keeps configs reachable via CMAKE_FIND_ROOT_PATH.

## Tests

- doctest + doctest_discover_tests under tests/, CTest mirrors build presets, BUILD_TESTING gate.
- Android JNI harness in tests/doctest_android_jni.cpp, device/emulator target documented in PR.

## Quality

cmake --build build/dev --target format tidy
- clang-format + cmake-format clean. clang-tidy on native only, never cross. pre-commit install once.

## CI

- Workflows start with yaml-language-server schema line.
- Matrix in cmake_multi_platform.yml (workflow_call). release.yml pipes it + publish-docker.yml, tags via softprops/action-gh-release, then PR bumps project(VERSION).
- Docker: matrix row in publish-docker.yml, ghcr.io/${{ github.repository }}/<name>. Pin bases. Dependabot watches /docker.
- New matrix entries use existing presets only.

## Cross

- Android: ./gradlew :app:assembleRelease --offline. abiFilters decides shipped .so. Keep unstripped .so. Symbolicate: ndk-stack -sym <dir> -dump tombstone.txt.
- llvm-mingw: cmake/toolchains/llvm_mingw.cmake, CMAKE_SYSTEM_PROCESSOR x86_64/i686/aarch64, auto-download tarball, --sysroot + lld baked in.
- Web: emsdk toolchain, wasm32 only.
- Profile with trace (Perfetto), not guesses.

## Packaging

- include(ct_cpack) then include(CPack) last, CPack reads vars at include-time.
- CPACK_VERBATIM_VARIABLES YES. COMPONENT runtime. File name os_compiler_arch.

## README

- readme.md <10KB. Quick start <=3 cmds. Links in docs/references.md. No sponsor badges.

## Commits

feat(ci): ..., fix(docker): ..., chore(docs): ..., deps: bump x to y.

## Agent rules

1. Unclear = ask, not guess. State assumptions.
2. Simpler wins. Push back on bloat.
3. Touch only request scope. Match style. Mention unrelated dead code, never delete.
4. Every changed line traces to request. Remove only orphans your change created.
5. Failing test first for fix/validation, pass before+after for refactor.
