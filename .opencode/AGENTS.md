# cmake_template

C++23. C+CXX. CMake 4.3+. Ninja Multi-Config. CPM. doctest + CTest.
Think first. Minimal diff. Verify with build + tests.

## AI files

- `.opencode/AGENTS.md` (this file) owns behavior. `.opencode/REVIEW.md`
  owns mechanical shape. `docs/references.md` owns links.
- `.opencode/opencode.jsonc` owns JSON config: MCP servers + repo
  references + `instructions` (this file + `.opencode/REVIEW.md`).
  Markdown lives elsewhere, never inline in JSON.
- `.opencode/commands/*.md` owns slash commands:
  `/ct_build` native loop, `/ct_cross_check` android/mingw/web,
  `/ct_add_preset` new platform preset, `/ct_add_dep` CPM dep,
  `/ct_review` diff, `/ct_reflect` corrections, `/ct_rebase` rebase,
  `/ct_release` version + changelog + commit.
- `.opencode/agents/ct_cmake_review.md` owns the read-only review subagent
  (`@ct_cmake_review`, `edit: deny`).
- `.opencode/ai-workflow-adapter.md` owns opencode mechanics (delegation,
  background builds, text handling). Loaded only when a command or agent
  explicitly asks for it; `.opencode/AGENTS.md` still wins on conflicts.
- `.opencode/readme.md` owns prompt-file conventions: naming, command vs
  agent vs skill, and the required shape of every new command/agent file.
- `.agents/shared/` owns workflow memory: `ct_project_context.md`,
  `ct_test_loop.md` (native vs cross). `.agents/skills/` is vendored
  third-party skills via `.agents/install_skills.cmake` + pinned
  `.agents/skills-lock.json` — not project workflow.
- `.agents/scripts/` owns runnable helpers: `rules/hook.py` enforces bans
  (`--staged` for pre-commit, stdin JSON for edit hooks),
  `clipboard/grab_clipboard.sh|.ps1` grabs clipboard images for UI reports.
- `.agents/skills/ct-auth/scripts/mcp_env_set.py` writes one env var from
  hidden console input to `ct_project.env` (same file the `ct_project_env`
  plugin reads). Dumb setter only — the `ct-auth` skill discovers what to
  fill live.

## Build

cmake --preset dev && cmake --build --preset dev -j && ctest --preset dev
ln -sf build/dev/compile_commands.json .

## Layout

- CMakeLists.txt — project(), CT_* cache vars, add_subdirectory(src), top-level only tests + packaging + CPack last
- CMakePresets.json — includes cmake/presets/*.json
- cmake/presets/ — base.json dev + build_release/debug + test_base, linux.json, windows.json, android.json, web.json
- cmake/toolchains/ — llvm_mingw.cmake, emscripten.cmake
- cmake/ct_cpm.cmake — fetch CPM, find_package(doctest, sdl3, gsl, imgui)
- cmake/cpm/ — package configs
- cmake/cpack/ct_cpack.cmake — DEB/RPM/NSIS metadata, CPACK_SYSTEM_NAME os_compiler_arch
- cmake/code_quality/ + cmake/scripts/
- src/ — 01_hello_world 02_sdl3_app 03_unity_build 04_tracy_profiler 05_webassembly 06_modules, one CMakeLists per dir
- tests/ — doctest_example.cpp, main.cpp, doctest_android_jni.cpp
- tools/ + scripts/ — python helpers, format/lint scripts
- docker/ — official-base images, no source COPY
- android_project/ — manifest + Gradle wrapper
- docs/references.md — links live here, not readme (see `docs/`)
- `.opencode/REVIEW.md` — mechanical review checklist for `/ct_review` + `@ct_cmake_review`
- `.agents/scripts/clipboard/` — `grab_clipboard.sh` (wl-paste/xclip) + `.ps1` (WinForms)

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

- C++23. Value types copy/move, share nothing. Follow Boost design best practices: https://www.boost.org/doc/contributor-guide/design-guide/design-best-practices.html
- snake_case types/funcs/vars. UPPER_CASE macros only. No m_, no Hungarian. Data members end with trailing `_` per .clang-tidy MemberSuffix.
- Files/dirs: lowercase snake_case, `_` separator, no hyphens (e.g. `logo_400.png`, `math_operations.cppm`). Rename on touch. Tool-mandated names stay: `CMakeLists.txt`, `.clang-format`/`.clang-tidy`, `.gitignore`/`.editorconfig`, GitHub UPPER docs, Android `res/` + `*.pro`, `*.Dockerfile`, `cmake/cpm/*-config.cmake` (package name).
- `.clang-format` / `.clang-tidy` stay extensionless: LLVM discovers only those exact names, `.yaml` suffix breaks it (verified via `clang-format --dump-config` + `clang-tidy --help`). They are YAML already; LSP via `# yaml-language-server` header.
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
- linux_gcc_x86_64_vcpkg + windows_msvc_x86_64_vcpkg (cmake/presets/vcpkg.json) — same trees via vcpkg manifest; need VCPKG_ROOT, CPM reuse ON.
- windows_msvc_x86_64 (VS17) + windows_llvm_mingw_x86/x86_64/aarch64, cross has no test presets.
- android_clang_aarch64/armv7/x86_64/x86, NDK + c++_shared + API24, tidy cleared, release (+debug aarch64/x86_64).
- web_emscripten_wasm32 via Emscripten toolchainFile, Node tests.
- No platform hacks in CI. Logic in presets/docker/toolchains.

## Deps

- CPM primary, vcpkg manifest optional. Tagged releases, not branches. FETCHCONTENT_QUIET OFF for CI.
- Options inside CPMAddPackage. vcpkg.json + vcpkg-configuration.json (registry baseline pinned) is an opt-in overlay: configure with `CMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake -DCPM_USE_LOCAL_PACKAGES=ON` to reuse it, otherwise CPM fetches.
- find_package(CONFIG REQUIRED) via cmake/cpm configs. Cross keeps configs reachable via CMAKE_FIND_ROOT_PATH.

## Tests

- doctest + doctest_discover_tests under tests/, CTest mirrors build presets, BUILD_TESTING gate.
- Android JNI harness in tests/doctest_android_jni.cpp, device/emulator target documented in PR.

## Quality

cmake --build build/dev --target format tidy
- clang-format + cmake-format clean. clang-tidy on native only, never cross. pre-commit install once.
- `/ct_review` (`.opencode/REVIEW.md` + `@ct_cmake_review`) is mechanical first-pass, changed lines only.
- `.agents/scripts/rules/hook.py --staged` blocks banned CMake/C++ before commit.

## CI

- Workflows start with yaml-language-server schema line.
- Matrix in cmake_multi_platform.yml (workflow_call). release.yml pipes it + publish-docker.yml, tags via softprops/action-gh-release, then PR bumps project(VERSION).
- Docker: manual dispatch only (`docker_ci` build, `docker_publish` push or via release input). Matrix row in publish-docker.yml, ghcr.io/${{ github.repository }}/<name>. Pin bases. Dependabot watches /docker.
- New matrix entries use existing presets only.
- CI-only build steps are ci_* targets in cmake/ct_ci.cmake (workflows name preset + target, never paths).

## Cross

- `/ct_cross_check [android|mingw|web|all]` — configure-only by default, no `ctest` on cross.
- Android: ./gradlew :app:assembleRelease --offline. abiFilters decides shipped .so. Keep unstripped .so. Symbolicate: ndk-stack -sym <dir> -dump tombstone.txt.
- llvm-mingw: cmake/toolchains/llvm_mingw.cmake, CMAKE_SYSTEM_PROCESSOR x86_64/i686/aarch64, auto-download tarball, --sysroot + lld baked in.
- Web: emsdk toolchain, wasm32 only.
- Profile with trace (Perfetto), not guesses.

## Packaging

- include(ct_cpack) then include(CPack) last, CPack reads vars at include-time.
- CPACK_VERBATIM_VARIABLES YES. COMPONENT runtime. File name os_compiler_arch.

## README

- readme.md <10KB. Quick start <=3 cmds. Links in docs/references.md. No sponsor badges.

## Text files

- LF only, UTF-8 without BOM. CRLF only for native non-WSL Windows checkouts.
- Clipboard images for UI bugs: `.agents/scripts/clipboard/grab_clipboard.sh out.png` (Linux) or `grab_clipboard.ps1 -OutPath out.png` (Windows). Attach PNG, never paste binary.

## Troubleshooting

- "preset not found": read `CMakePresets.json` includes + `cmake/presets/*.json`. Never invent `cmake -D` lines.
- Cross test failure: cross has no CTest. Android -> `./gradlew connectedCheck`, web -> Node, mingw -> no tests.
- `Libraries not found` (Android/web): NDK/emsdk path comes from preset/toolchain, not from env hacks in `CMakeLists.txt`.

## Commits

feat(ci): ..., fix(docker): ..., chore(docs): ..., deps: bump x to y.
- `[ai] ` prefix only when every retained change is AI workflow only (`.opencode/AGENTS.md`, `.opencode/REVIEW.md`, `.opencode/`, `.agents/`, commands/agents). Product + workflow mixed = no prefix. Never add `Co-Authored-By` or tool trailers.

## Agent rules

1. Unclear = ask, not guess. State assumptions.
2. Simpler wins. Push back on bloat.
3. Touch only request scope. Match style. Mention unrelated dead code, never delete.
4. Every changed line traces to request. Remove only orphans your change created.
5. Failing test first for fix/validation, pass before+after for refactor.
