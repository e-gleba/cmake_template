# Platforms Guide

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