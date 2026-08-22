# cmake_template

<p align="center">
  <img src=".github/logo.png" alt="cmake_template logo" width="200"/>
</p>

<p align="center">
  <a href="https://github.com/e-gleba/cmake_template/blob/main/license.md"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"/></a>
  <a href="https://github.com/e-gleba/cmake_template/actions/workflows/cmake_multi_platform.yml"><img src="https://img.shields.io/github/actions/workflow/status/e-gleba/cmake_template/cmake_multi_platform.yml?branch=main&label=ci" alt="ci"/></a>
  <a href="https://github.com/e-gleba/cmake_template/releases"><img src="https://img.shields.io/github/v/release/e-gleba/cmake_template" alt="release"/></a>
  <a href="https://isocpp.org/"><img src="https://img.shields.io/badge/C%2B%2B-23%2F26-00599C?logo=cplusplus&logoColor=white" alt="C++ Standard"/></a>
  <a href="https://cmake.org"><img src="https://img.shields.io/badge/CMake-4.4%2B-064F8C?logo=cmake" alt="CMake"/></a>
</p>

<p align="center">
  <a href="https://github.com/e-gleba/cmake_template/actions/workflows/release.yml"><img src="https://img.shields.io/badge/%E2%96%B6_run-release-2ea44f" alt="Run release"/></a>
  <a href="https://github.com/e-gleba/cmake_template/actions/workflows/publish-docker.yml"><img src="https://img.shields.io/badge/%E2%96%B6_run-publish--docker-2ea44f" alt="Run publish-docker"/></a>
  <a href="https://github.com/e-gleba/cmake_template/actions/workflows/cmake_multi_platform.yml"><img src="https://img.shields.io/badge/%E2%96%B6_run-ci-2ea44f" alt="Run CI"/></a>
  <a href="https://github.com/e-gleba/cmake_template/actions/workflows/renovate.yml"><img src="https://img.shields.io/badge/%E2%96%B6_run-renovate-2ea44f" alt="Run Renovate"/></a>
</p>

<p align="center">
  <b>The only CMake template with Android NDK, Linux→Windows cross-compilation, WebAssembly, and Gradle Managed Devices — out of the box.</b>
</p>

<p align="center">
  <a href="https://github.com/e-gleba/cmake_template/generate"><img src="https://img.shields.io/badge/Use%20this%20template-Generate%20new%20repo-238636?logo=github" alt="Use this template"/></a>
</p>

---

Production-ready C++ template for cross-platform projects. Targets C++23/26. Ninja Multi-Config, CPM, clang-tidy, clang-format, pre-commit hooks. Packages with CPack. Tests with doctest — instrumented on Android via Gradle Managed Devices, run under Node.js on WebAssembly. Zero friction from clone to package on **Linux, Windows, Android, macOS, and WebAssembly**.

```bash
# Desktop — full pipeline in one command
cmake --workflow --preset=gcc-full

# Android — configure + build for arm64
cmake --workflow --preset=android-arm64-full

# Linux → Windows ARM64 — cross-compile + package
cmake --workflow --preset=llvm-mingw-aarch64-full
```

**Release:** click [▶ run release](https://github.com/e-gleba/cmake_template/actions/workflows/release.yml), type `v1.2.3` and next CMake version (`1.2.4`). Builds every platform, optionally pushes GHCR images, tags, attaches CPack/APK artifacts, then opens+merges a PR bumping `project(VERSION)` on main.

---

## Why this template?

| You need | Most templates | This template |
|---|---|---|
| **Android NDK** | ❌ Not even mentioned | ✅ 4 presets (arm64, arm32, x64, x86), API 24, `c++_shared`, Prefab |
| **Android instrumentation tests** | ❌ | ✅ `AndroidJUnitRunner`, Gradle Managed Devices (Pixel 6 ATD), doctest JNI bridge, [#23 native GTest strategy](https://github.com/e-gleba/cmake_template/issues/23) |
| **Linux → Windows cross-compile** | ❌ | ✅ llvm-mingw toolchain: x86_64, i686, aarch64 |
| **WebAssembly** | ❌ | ✅ Emscripten preset with zero-setup SDK bootstrap, SDL3 + ImGui + OpenGL web demo, doctest under Node.js |
| **CMake Presets** | Basic or none | ✅ 10+ configure presets, 15+ build presets, workflow presets, schema v12 |
| **Packaging** | ❌ | ✅ CPack: tar.gz, zip, txz per platform |
| **Reproducible CI** | Manual Docker | ✅ Docker images + GitHub Actions matrix |
| **One-click release** | ❌ | ✅ `workflow_dispatch` + GHCR + CPack/APK attach |
| **Code quality** | Maybe clang-format | ✅ clang-tidy, clang-format, `.cmake-format.yaml`, pre-commit hooks, `.editorconfig` |
| **C++ Standard** | 17 | ✅ **23 / 26** |

---

## Quick Start

### 1. Create your repo from this template

<p align="center">
  <a href="https://github.com/e-gleba/cmake_template/generate"><b>Click here: Use this template → Create new repository</b></a>
</p>

Then clone your new repo:

```bash
git clone https://github.com/YOUR_USER/YOUR_PROJECT
cd YOUR_PROJECT
```

### 2. Build and test (desktop)

```bash
# GCC — full pipeline
cmake --workflow --preset=gcc-full

# Or step by step:
cmake --preset=gcc
cmake --build --preset=gcc-release
ctest --preset=gcc-release

# Clang
cmake --workflow --preset=clang-full

# MSVC (Windows only)
cmake --workflow --preset=msvc-full
```

### 3. Cross-compile for Android

```bash
# Requires: ANDROID_NDK_HOME or ANDROID_HOME set
cmake --preset=android-arm64
cmake --build --preset=android-arm64

# Run instrumented tests on device/emulator
cd android-project
./gradlew pixel_6_aosp_atd_30DebugAndroidTest
./gradlew connectedCheck
```

### 4. Cross-compile for Windows (from Linux)

```bash
# Requires: llvm-mingw installed
cmake --workflow --preset=llvm-mingw-x86_64-full
# → build/llvm-mingw-x86_64/package/cxx_project-*.zip
```

### 5. WebAssembly (zero setup)

```bash
# No emsdk install needed — the toolchain bootstraps a pinned SDK into .emsdk/
cmake --workflow --preset=emscripten-full
# → build/emscripten/src/emscripten/Release/web_app.{html,js,wasm}
```

---

## Platform Matrix

| Platform | Preset | Generator | Test runner | Package |
|---|---|---|---|---|
| **Linux (native)** | `gcc`, `clang` | Ninja Multi-Config | `ctest` | `.tar.gz` |
| **Windows (native)** | `msvc` | Visual Studio 17 2022 | `ctest` | `.zip` |
| **Windows (cross)** | `llvm-mingw-x86_64`, `llvm-mingw-i686`, `llvm-mingw-aarch64` | Ninja Multi-Config | — (cross-compiled) | `.tar.xz` |
| **Android arm64** | `android-arm64` | Ninja Multi-Config | `gradlew connectedCheck` | — |
| **Android arm32** | `android-arm32` | Ninja Multi-Config | `gradlew connectedCheck` | — |
| **Android x64** | `android-x64` | Ninja Multi-Config | `gradlew connectedCheck` | — |
| **Android x86** | `android-x86` | Ninja Multi-Config | `gradlew connectedCheck` | — |
| **macOS** | `clang` (native) | Ninja Multi-Config | `ctest` | `.tar.gz` |
| **iOS / macOS Xcode** | [planned #20](https://github.com/e-gleba/cmake_template/issues/20) | Xcode | `xctest` / `xcodebuild test` | — |
| **WebAssembly** | `emscripten` | Ninja Multi-Config | `ctest` via Node.js | `.html` + `.js` + `.wasm` |

---

## Comparison: Competitive Landscape

| Feature | **cmake_template** | [cpp-best-practices](https://github.com/cpp-best-practices/cmake_template) | [modern-cpp-template](https://github.com/filipdutescu/modern-cpp-template) | [cmake-init](https://github.com/cginternals/cmake-init) |
|---|---|---|---|---|
| **C++ Standard** | **23 / 26** | 17 / 20 | 17 | 11+ |
| **CMake Presets** | ✅ 10+ with workflows | ❌ | ❌ | ❌ |
| **Android NDK** | ✅ 4 ABI | ❌ | ❌ | ❌ |
| **Android instrumented tests** | ✅ GMD + doctest JNI | ❌ | ❌ | ❌ |
| **Linux → Windows cross** | ✅ llvm-mingw (3 arch) | ❌ | ❌ | ❌ |
| **WebAssembly** | ✅ Emscripten (SDL3 + ImGui + OpenGL demo) | ✅ + Pages deploy | ❌ | ❌ |
| **Docker / CI** | ✅ + Actions matrix | ✅ Docker + Actions | ✅ GitHub Actions | ✅ |
| **CPack packaging** | ✅ tar.gz / zip / txz | ❌ | ❌ | ❌ |
| **Sanitizers** | ❌ [#9](https://github.com/e-gleba/cmake_template/issues/9) | ✅ ASan/UBSan | ✅ | ❌ |
| **Fuzz testing** | ❌ | ✅ libFuzzer | ❌ | ❌ |
| **Code coverage** | ❌ [#10](https://github.com/e-gleba/cmake_template/issues/10) | ✅ codecov | ✅ codecov | ❌ |
| **macOS/iOS (Xcode)** | ❌ [#20](https://github.com/e-gleba/cmake_template/issues/20) | Limited | ❌ | ❌ |
| **vcpkg** | ❌ [#3](https://github.com/e-gleba/cmake_template/issues/3) | ❌ | ❌ | ❌ |
| **GitHub Stars** | *you are here* | 1,700+ | 1,900+ | 900+ |
| **Age** | ~1 year | 3 years | 5 years | 11 years |
| **License** | MIT | Unlicense | Unlicense | MIT |

---

## Documentation

| Document | What it covers |
|---|---|
| [Presets & Platforms](docs/presets.md) | All CMake presets, platform support, cross-compilation details |
| [Architecture](docs/architecture.md) | CMake design decisions, directory structure, `PROJECT_IS_TOP_LEVEL` pattern |
| [Docker Guide](docs/docker.md) | Docker images, GHCR publish, one-click release |
| [Contributing](docs/contributing.md) | How to contribute, code style, pre-commit setup |
| [References](docs/references.md) | Curated external links (do NOT bloat README) |
| [Issue: Android native testing strategy](https://github.com/e-gleba/cmake_template/issues/23) | GTest vs doctest, Activity lifecycle, XCTest, CI/CD — research-backed |

---

## Consulting

I help teams reduce C++ build friction and ship cross-platform products faster.

**Services:**
- CMake architecture audits and modernisation
- Android NDK toolchain setup and Gradle integration
- CI/CD pipeline design for C++ (GitHub Actions, GitLab CI, Docker)
- Cross-compilation pipelines (Linux→Windows, Linux→Android, macOS→iOS)
- CPack packaging and distribution
- Team onboarding workshops

**Why work with me:**
- This template is the public portfolio — it demonstrates real engineering depth in CMake, NDK, cross-compilation, and CI
- I focus exclusively on **build engineering** — not general software consulting
- Every engagement starts with a concrete deliverable, not a roadmap document

<p align="center">

| | |
|---|---|
| 🌐 **Website** | [e-gleba.github.io](https://e-gleba.github.io) |
| 📧 **Email** | [i@egleba.ru](mailto:i@egleba.ru) — fastest response |
| 💬 **Discussions** | [GitHub Discussions](https://github.com/e-gleba/cmake_template/discussions) |
| 💼 **Rate** | Up to $150/hr depending on scope |
| 📍 **Location** | Remote-first, worldwide |

</p>

---

<div align="center">
<sub>MIT — use it for anything: commercial products, internal tools, or as a base for your own template · <a href="license.md">license.md</a></sub>
</div>
