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