# cmake_template

<p align="center">
  <img src=".github/logo.png" alt="cmake_template logo" width="200"/>
</p>

<p align="center">
  <a href="https://github.com/e-gleba/cmake_template/actions/workflows/cmake_multi_platform.yml"><img src="https://img.shields.io/github/actions/workflow/status/e-gleba/cmake_template/cmake_multi_platform.yml?branch=main&style=for-the-badge&labelColor=1C1C1C&logo=github&label=CI" alt="CI"/></a>
  <a href="https://isocpp.org/"><img src="https://img.shields.io/badge/C%2B%2B-23%2F26-00599C?style=for-the-badge&logo=cplusplus&logoColor=white&labelColor=1C1C1C" alt="C++ Standard"/></a>
  <a href="https://cmake.org"><img src="https://img.shields.io/badge/CMake-3.31%2B-064F8C?style=for-the-badge&logo=cmake&logoColor=white&labelColor=1C1C1C" alt="CMake"/></a>
  <a href="https://github.com/e-gleba/cmake_template/blob/main/license.md"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge&labelColor=1C1C1C" alt="License"/></a>
  <a href="docs/contributing.md"><img src="https://img.shields.io/badge/Contributing-Guide-4CAF50?style=for-the-badge&labelColor=1C1C1C" alt="Contributing Guide"/></a>
</p>

Production-ready C++ template with **Android NDK**, **cross-compilation to Windows**, **Docker**, **CPack**, and **one-command CI pipelines**. Targets C++23/26. Ninja Multi-Config, CPM, code-quality tooling — zero friction from clone to package.

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

## Why this template?

Most CMake starters stop at "it builds on my machine". This template goes further with first-class cross-compilation and packaging.

- **Android NDK out of the box** — 4 presets (arm64, arm32, x64, x86) with API 24.
- **Linux → Windows cross-compile** — 3 llvm-mingw presets (x86_64, i686, aarch64).
- **Reproducible builds** — Docker images for CI and local development.
- **One-command pipelines** — `cmake --workflow` handles configure → build → test → package.
- **Modern standards** — C++23/26 with clang-tidy, clang-format, IWYU-ready structure.
- **Professional documentation** — upgraded [CONTRIBUTING.md](docs/contributing.md) and consolidated [Presets/Platforms guide](docs/presets.md).

## Comparison

| Feature | cmake_template | [cpp-best-practices](https://github.com/cpp-best-practices/cmake_template) | [kigster](https://github.com/kigster/cmake-project-template) | [district10](https://github.com/district10/cmake-templates) | [pamplejuce](https://github.com/sudara/pamplejuce) |
| :-- | :--: | :--: | :--: | :--: | :--: |
| Pitch | Generic C++ starter with cross-compile | Opinionated best-practice starter | Minimal C/C++ starter | Qt / Boost / OpenCV examples | JUCE audio plugins |
| C++ Standard | **23 / 26** | 17 / 20 | unspecified | **11** | unspecified |
| CMake Presets | 10+ with workflows | — | basic | — | JUCE-oriented |
| Android NDK | ✅ | ❌ | ❌ | ❌ | ❌ |
| Android instrumentation (tests) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Linux → Windows cross | ✅ llvm-mingw | ❌ | ❌ | ❌ | ❌ |
| WebAssembly | ❌ [planned (#2)](https://github.com/e-gleba/cmake_template/issues/2) | ✅ + GitHub Pages deploy | ❌ | ❌ | ❌ |
| Docker / CI-ready | ✅ Dockerfile + GitHub Actions | ✅ Docker + Actions | ❌ | ❌ | ✅ GitHub Actions |
| CPack packaging | ✅ tar.gz / zip / tar.xz | ❌ | ❌ | ❌ | ❌ |
| CTest test runner | ✅ | ✅ | ❌ | ❌ | ❌ |
| Dependency manager | CPM + [prebuilt/air-gapped (#8)](https://github.com/e-gleba/cmake_template/issues/8) | CPM | — | — | — |
| vcpkg compatibility | ❌ [planned (#3)](https://github.com/e-gleba/cmake_template/issues/3) | ❌ | ❌ | ❌ | ❌ |
| Sanitizers (ASan/UBSan) | ❌ [planned (#9)](https://github.com/e-gleba/cmake_template/issues/9) | ✅ | ❌ | ❌ | ❌ |
| Fuzz testing | ❌ | ✅ libFuzzer | ❌ | ❌ | ❌ |
| Codecov / CodeQL | ❌ [planned (#10)](https://github.com/e-gleba/cmake_template/issues/10) | ✅ | ❌ | ❌ | ❌ |
| Steam Runtime / Steam Deck | ❌ [planned (#11)](https://github.com/e-gleba/cmake_template/issues/11) | ❌ | ❌ | ❌ | ❌ |
| Qt / OpenGL | ❌ | ❌ | ❌ | ✅ | ❌ |
| Audio / JUCE | ❌ | ❌ | ❌ | ❌ | ✅ |
| C++20 modules | ❌ [planned (#5)](https://github.com/e-gleba/cmake_template/issues/5) | ❌ | ❌ | ❌ | ❌ |
| macOS / iOS (Xcode presets) | ❌ [planned (#20)](https://github.com/e-gleba/cmake_template/issues/20) | Limited | ❌ | ❌ | Specialized |

> Honest notes: this template is intentionally generic — it does not include Qt, OpenGL, audio scaffolding, or fuzz testing. Those are well covered by specialized starters above. We focus on cross-platform build engineering and packaging. See the new consolidated [presets.md](docs/presets.md) for current platform support and detailed macOS/iOS roadmap.

## Consulting

Need help with **CMake architecture**, **cross-compilation pipelines**, **CI/CD for C++**, or **packaging with CPack**? I help teams reduce build friction and ship faster.

- 🌐 [e-gleba.github.io](https://e-gleba.github.io) — contacts, portfolio, and blog
- 📧 <i@egleba.ru> — direct inquiries (fastest response)
- 💼 Open for **freelance** and **contract work** (up to $150/hr depending on scope)
- 🛠️ Services: CMake audits, toolchain setup, Docker/CI optimization, custom presets, onboarding workshops

For inquiries, reach out via email or through the website above, or open a [Discussion](https://github.com/e-gleba/cmake_template/discussions).

---

## More details

- [Presets, Platforms & Cross-Compilation (consolidated)](docs/presets.md)
- [Docker Guide](docs/docker.md)
- [Architecture](docs/architecture.md)
- [References](docs/references.md)
- [Contributing](docs/contributing.md)

**Roadmap note**: macOS/iOS Xcode support is now prominently planned in [#20](https://github.com/e-gleba/cmake_template/issues/20). Many other enhancements tracked in open issues.
