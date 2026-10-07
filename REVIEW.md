# Code Review Style Guide

Mechanical checks for the review agent and `/review` command.
`AGENTS.md` owns behavior; this file owns shape. Where they conflict,
`AGENTS.md` wins and this file gets fixed.

## CMake (all `CMakeLists.txt`, `cmake/**/*.cmake`, presets)

- Targets only. Flag `include_directories()`, `link_libraries()`,
  `add_definitions()`, `CMAKE_CXX_FLAGS` mutation.
- No `file(GLOB)`. Explicit sources.
- No `CMAKE_BUILD_TYPE` in project files. Preset owns it
  plus `CMAKE_CONFIGURATION_TYPES`.
- `CT_*` user cache vars/options, `ct_*` targets/functions/locals.
  Upstream names untouched.
- `PUBLIC` propagates, `PRIVATE` not, `INTERFACE` consumers-only.
- Alias every exported lib.
- Warnings per-compiler guarded, never `PUBLIC`.
- Generated files in binary dir only.
- `PROJECT_IS_TOP_LEVEL` gates tests/packaging.
  Use `PROJECT_SOURCE_DIR`, never `CMAKE_SOURCE_DIR` in modules.
- Cross logic lives in `cmake/presets/*.json` or
  `cmake/toolchains/*.cmake`, never inline `if(WIN32)` hacks in `src/`.

## C++23 (`src/**`, `tests/**`)

- `{}` over `()`. Init every variable. RAII only, no `new`/`delete`.
- `class` for invariants, `struct` for data. `final` on non-base.
  Rule of zero. No owning raw pointers.
- `std::int32_t`/`uint32_t`/`int64_t`/`uint64_t` with `std::`.
  `size_t` sizes, `ptrdiff_t` diffs.
- `span`/`string_view` by value, never stored.
- `[[nodiscard]]` on declarations, not repeated on out-of-class definitions.
- `expected<T,E>` for fallible, no magic values.
- `gsl::Expects`/`Ensures` for contracts. `const` default,
  `constexpr` free, `noexcept` honest.
- `snake_case` types/funcs/vars. `UPPER_CASE` macros only.
  Data members end with trailing `_`.
- One argument per line when a call splits. Max one empty line.
  Operators at start of continuation lines.

## Includes

- After own header, sort alphabetically, nested folders first,
  `styles/style_*.h` last (tdesktop rule, same discipline here).
- Never add file-scope `using namespace`.

## Tests

- doctest only. Flag gtest/catch2 includes.
- Register via `doctest_discover_tests()` in `tests/CMakeLists.txt`.
- CTest preset names mirror build presets.

## Workflows (`.github/workflows/**`)

- Schema comment first (`yaml-language-server`).
- Matrix lives only in `cmake_multi_platform.yml`. No duplicated matrix.
- No platform hacks in CI. Logic in presets/docker/toolchains.
- Pin actions. Images `ghcr.io/${{ github.repository }}/<name>`.

## Docs

- `readme.md` <10KB. Quick start <=3 commands.
- Links live in `docs/references.md`, not in readme.
