# 06_modules - C++20 named modules

Demo of C++20 modules on modern CMake. Nothing to enable: at configure
time the CMakeLists compiles a minimal module with `try_compile` - one
ground-truth test for compiler, dependency scanner, generator, and build
tool - and reports through `message(CHECK_START ...)`. Unsupported
toolchains skip the target, so every preset keeps configuring cleanly.
The probe result is cached; clear the CMake cache to re-probe after a
toolchain change.

```bash
cmake --preset gcc && cmake --build --preset gcc-release --target 06_modules
./build/gcc/src/06_modules/Release/06_modules
```

The executable opens an SDL3 hello-world window when a display exists
and falls back to CLI output when headless. Either way it self-checks
every feature below and exits non-zero on mismatch.

## What it exercises

| File | Module unit | Feature demonstrated |
| --- | --- | --- |
| `cxx_project.cppm` | primary interface unit | named module, exported aggregate, `export import :math;` re-export |
| `cxx_project-math.cppm` | interface partition | `module cxx_project:math`, exported concept + constrained template, `constexpr` through the BMI |
| `cxx_project.impl.cpp` | implementation unit | interface/implementation split; plain `.cpp` + `module cxx_project;` |
| `cxx_project.utility.cppm` | single-TU module | private module fragment (`module :private;`), inter-module `import` |
| `main.cpp` | consumer | `import`, compile-time `static_assert` from the BMI, `#include`/`import` interop, SDL3 window |

## Requirements

The probe compiles a real module, so the whole chain is verified at
once; a failed probe skips the target instead of erroring. Effective
minimums:

| Toolchain | Minimum | Notes |
| --- | --- | --- |
| CMake | 3.28 (project floor: 4.4) | `FILE_SET CXX_MODULES` |
| Ninja | 1.11 | required by the Ninja generators |
| MSVC | 14.34 (VS 2022 17.4) | VS generator or Ninja |
| Clang | 16 | needs `clang-scan-deps` next to the compiler - Debian/Ubuntu: `apt install clang-tools` |
| GCC | 14 | `-fdeps-format=p1689r5` dependency scanning |

Generators with module scanning support: Ninja, Ninja Multi-Config,
Visual Studio 17 2022 and newer. Cross toolchains are probed like any
other: if the cross compiler can build a module, the demo is built.

## Known limitations

- **Header units** (`import <vector>;`) are not supported by CMake on any
  generator. Use the global module fragment (`module;` + `#include`), as
  every unit here does.
- **`import std;`** is still experimental in CMake 4.4: gated behind
  `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` + `CMAKE_CXX_MODULE_STD`, Ninja
  generators only, Clang >= 18.1.2 / MSVC >= 14.36 / GCC >= 15 - and
  Ubuntu < 26.04 ships a broken `libstdc++.modules.json`
  ([Ubuntu issue 2141579](https://bugs.launchpad.net/ubuntu/+bug/2141579)).
  Not enabled here on purpose.
- **Private module fragment** units must be the *only* unit of their
  module ([module.private.frag](https://eel.is/c++draft/module.private.frag))
  - that is why the fragment demo lives in its own module,
  `cxx_project.utility`.
- **Module visibility is enforced**: a module from a `PRIVATE` file set
  cannot be imported by other targets. Fine for executables; libraries
  exporting modules need a `PUBLIC` file set (and Ninja - the VS
  generators cannot install/export BMIs).
- **Implementation units**: plain `.cpp` and `module M;` only. A
  `module M:part;` declaration in an implementation unit is an internal
  partition that only MSVC accepts; CMake errors on it elsewhere.

## References

- [CMake `cmake-cxxmodules(7)`](https://cmake.org/cmake/help/latest/manual/cmake-cxxmodules.7.html)
- [CMake `try_compile`](https://cmake.org/cmake/help/latest/command/try_compile.html)
- [Kitware - Import CMake C++20 Modules](https://www.kitware.com/import-cmake-c-20-modules/)
- [cppreference - Modules](https://en.cppreference.com/w/cpp/language/modules)
- [Clang - Standard C++ Modules](https://clang.llvm.org/docs/StandardCPlusPlusModules.html)
- [GCC C++ Modules Wiki](https://gcc.gnu.org/wiki/cxx-modules)
- [MSVC - C++20 modules with CMake in VS 2022 17.4](https://devblogs.microsoft.com/cppblog/standard-c20-modules-support-with-cmake-in-visual-studio-2022-version-17-4/)
