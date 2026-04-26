# cmake_template

<p align="center">
  <img src=".github/logo.png" alt="cxx-skeleton logo" width="200"/>
</p>

<p align="center">
  <a href="https://github.com/e-gleba/cmake_template/actions/workflows/cmake_multi_platform.yml"><img src="https://img.shields.io/github/actions/workflow/status/e-gleba/cmake_template/cmake_multi_platform.yml?branch=main&style=for-the-badge&labelColor=1C1C1C&logo=github&label=CI" alt="CI"/></a>
  <a href="https://isocpp.org/"><img src="https://img.shields.io/badge/C%2B%2B-23%2F26-00599C?style=for-the-badge&logo=cplusplus&logoColor=white&labelColor=1C1C1C" alt="C++ Standard"/></a>
  <a href="https://cmake.org"><img src="https://img.shields.io/badge/CMake-3.31%2B-064F8C?style=for-the-badge&logo=cmake&logoColor=white&labelColor=1C1C1C" alt="CMake"/></a>
  <a href="license.md"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge&labelColor=1C1C1C" alt="License"/></a>
</p>

Modern C++ project template. Ninja Multi-Config, CPM, CPack, cross-compilation, code quality tooling — zero friction from clone to package.

## Quick Start

```bash
cmake --preset=gcc
cmake --build --preset=gcc-release
ctest --preset=gcc-release
```

Full pipeline (configure → build → test → package):

```bash
cmake --workflow --preset=gcc-full
```

## Prerequisites

```
cmake 3.31+
ninja 1.11+
C++23-capable compiler (clang 16+, gcc 13+, msvc 19.35+)
```

### macOS

```bash
brew install cmake llvm ninja doxygen
```

### Linux (Fedora)

```bash
sudo dnf install cmake gcc-c++ ninja-build doxygen llvm clang-tools-extra
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install cmake g++ ninja-build doxygen llvm clang-tools
```

### Windows

```powershell
choco install cmake llvm ninja doxygen visualstudio2022buildtools
```

## Presets

All presets use **Ninja Multi-Config** (except `msvc` → Visual Studio 17 2022).

### Configure

| Preset | Compiler | Platform | Notes |
| :-- | :-- | :-- | :-- |
| `gcc` | GCC/G++ | Native | — |
| `clang` | Clang/Clang++ | Native | — |
| `msvc` | MSVC (VS 2022) | Windows | x64 arch, x64 host toolset |
| `android-arm64` | NDK | Android | arm64-v8a, API 24 |
| `android-arm32` | NDK | Android | armeabi-v7a, API 24 |
| `android-x64` | NDK | Android | x86_64 (emulator) |
| `android-x86` | NDK | Android | x86 (emulator) |
| `llvm-mingw-x86_64` | LLVM-MinGW | Linux → Windows | 64-bit cross-compilation |
| `llvm-mingw-i686` | LLVM-MinGW | Linux → Windows | 32-bit cross-compilation |
| `llvm-mingw-aarch64` | LLVM-MinGW | Linux → Windows | ARM64 cross-compilation |

### Build

```bash
cmake --build --preset=<name>-release
cmake --build --preset=<name>-debug
```

Available: `gcc-release`, `gcc-debug`, `clang-release`, `clang-debug`, `msvc-release`, `msvc-debug`, `android-arm64`, `android-arm32`, `android-x64`, `android-x86`, `llvm-mingw-x86_64`, `llvm-mingw-i686`, `llvm-mingw-aarch64`.

### Test

```bash
ctest --preset=<name>-release
```

Available: `gcc-release`, `gcc-debug`, `clang-release`, `clang-debug`, `msvc-release`, `msvc-debug`. Tests are disabled for cross-compiled targets.

### Package (CPack)

```bash
cpack --preset=<name>-package
```

| Preset | Format |
| :-- | :-- |
| `gcc-package` | `.tar.gz` |
| `clang-package` | `.tar.gz` |
| `msvc-package` | `.zip` |
| `llvm-mingw-*-package` | `.tar.xz` |

### Workflows

Full pipelines (configure → build → test → package) in a single command:

```bash
cmake --workflow --preset=gcc-full
cmake --workflow --preset=clang-full
cmake --workflow --preset=msvc-full
cmake --workflow --preset=android-arm64-full    # configure + build only
cmake --workflow --preset=llvm-mingw-x86_64-full # configure + build + package (no test)
```

## Project Structure

```
.
├── CMakeLists.txt
├── CMakePresets.json
├── cmake/                  # find_package modules (warnings, cpm, code quality)
├── src/                    # application sources
├── tests/                  # doctest + CTest
├── tools/                  # helper scripts
├── docker/                 # Dockerfiles for reproducible builds
├── android-project/        # Android project scaffolding
├── .clang-format           # clang-format config
├── .clang-tidy             # clang-tidy config
├── .cmake-format.yaml      # cmake-format config
├── .editorconfig           # editor defaults
├── .pre-commit-config.yaml # pre-commit hooks
└── license                 # MIT
```

## Code Quality

Format sources and CMake files:

```bash
cmake --build build/gcc --target format
```

Static analysis:

```bash
cmake --build build/gcc --target tidy
```

Lint:

```bash
cmake --build build/gcc --target cpplint
```

Pre-commit hooks enforce formatting on every commit. Install once:

```bash
pre-commit install
```

## Documentation

```bash
cmake --build build/gcc --target doxygen
```

Output: `build/gcc/docs/doxygen/html`.

## Docker

```bash
docker build -t cxx-skeleton -f docker/fedora.Dockerfile .
docker run --rm -v "$(pwd):/src" cxx-skeleton cmake --workflow --preset=gcc-full
```

## Android

Set `ANDROID_NDK_HOME` and run:

```bash
export ANDROID_NDK_HOME=/path/to/ndk
cmake --workflow --preset=android-arm64-full
```

## Cross-Compilation (Linux → Windows)

Requires [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) on `PATH`:

```bash
cmake --workflow --preset=llvm-mingw-x86_64-full
```

## Dependencies

Managed via [CPM](https://github.com/cpm-cmake/CPM.cmake). Add packages in CMakeLists.txt:

```cmake
CPMAddPackage("gh:fmtlib/fmt#11.1.4")
```

CPM downloads are verbose (`FETCHCONTENT_QUIET=OFF`) for CI visibility.

## IDE Support

The project generates `compile_commands.json` and is compatible with CLion, Visual Studio, QtCreator, KDevelop, and any LSP-based editor.

---

Curated C++ ecosystem links — standards, tooling, and community references — are maintained in [docs/references.md](docs/references.md).
