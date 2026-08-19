# Docker Guide

**Reproducible toolchain images for cmake_template.**

Images hold the compiler stack (CMake 3.31+, GCC/Clang, Ninja, Doxygen). Source is **not** baked in — mount the repo at `/app`. Same image works locally and in CI.

## Available Images

| Image | Base | Use case |
|-------|------|----------|
| `fedora` | `fedora:44` (official, pinned) | Primary CI / development. Dependabot bumps the tag. |
| `manjaro` | `manjarolinux/base:latest` (official) | Rolling validator. Bleeding-edge compilers. |

> Linux native (`gcc`, `clang`) and `llvm-mingw-*` (toolchain mounted). Android uses the host NDK. macOS/iOS need a macOS host.

Published to `ghcr.io/<owner>/<repo>/<name>` by [`.github/workflows/publish-docker.yml`](../.github/workflows/publish-docker.yml).

## Quick Start

### Build

Context is `docker/` so the rest of the repo never enters the image.

```bash
docker build -t cmake-template:fedora -f docker/fedora.Dockerfile docker
docker build -t cmake-template:manjaro -f docker/manjaro.Dockerfile docker
```

### Run Full Workflow

Default `ENTRYPOINT` is `cmake --workflow --preset=gcc-full`:

```bash
docker run --rm -v "$(pwd):/app" cmake-template:fedora
```

CPack packages land in the host `build/` tree.

### Interactive

```bash
docker run --rm -it -v "$(pwd):/app" --entrypoint bash cmake-template:fedora
# inside:
cmake --preset=clang
cmake --build --preset=clang-release
ctest --preset=clang-release
```

### Linux → Windows Cross

Mount llvm-mingw; it is not in the image.

```bash
docker run --rm -it \
  -v "$(pwd):/app" \
  -v "/path/to/llvm-mingw:/opt/llvm-mingw" \
  --entrypoint bash cmake-template:fedora
export PATH="/opt/llvm-mingw/bin:$PATH"
cmake --workflow --preset=llvm-mingw-x86_64-full
```

## Architecture

Single stage. Toolchain only.

- **BuildKit cache mounts** persist `dnf` / `pacman` caches.
- **One `RUN` for system deps** — fewer layers.
- **No `COPY` of source** — image is a compiler, not a snapshot. Mount the repo.
- **`ENTRYPOINT` = `gcc-full`** — `docker run` == one CI job.
- **`SOURCE` build-arg** — OCI `org.opencontainers.image.source`. Forks need no Dockerfile edit.

```
Layer 1: Official base (fedora:44 / manjarolinux/base)
Layer 2: System packages (cached across source changes)
Layer 3: ENTRYPOINT
```

## GHCR Tags

`publish-docker.yml` (official `docker/*` actions) tags:

| Tag | When |
|-----|------|
| `latest` | Default branch |
| `<version>` | Release input / dispatch extra tag |
| `sha-<short>` | Every build |
| `<branch>` | Branch push |

Add an image: one row in `jobs.publish.strategy.matrix.include`.

## Release Pipe

[`.github/workflows/release.yml`](../.github/workflows/release.yml) is `workflow_dispatch`. It:

1. Calls `publish-docker.yml` (optional, parallel, one job per image).
2. Calls `cmake_multi_platform.yml` (same matrix as CI — no duplicated jobs).
3. Tags `vX.Y.Z` and attaches CPack / APK artifacts via `gh release create`.
4. Opens + squash-merges a PR that bumps `project(VERSION)` in `CMakeLists.txt` to the `next_version` you typed. The just-shipped tag stays at the old version.

Click **▶ run release** on the README, type `v1.2.3` and next CMake version `1.2.4`.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `cmake: command not found` | Base drifted | Rebuild `--no-cache`; check Dependabot pin |
| Slow rebuilds | No cache mount | `DOCKER_BUILDKIT=1` |
| Permission errors on `build/` | Container uid ≠ host | `--user $(id -u):$(id -g)` |
| NDK not found | Not mounted | Host NDK or a dedicated Android image |
| `llvm-mingw` fails | Not on PATH | Mount the toolchain volume |

## Extending

1. Copy `docker/fedora.Dockerfile`.
2. Swap the package manager. Keep official base images.
3. Need: `cmake >= 3.31`, `ninja`, `gcc`/`clang`, `git`, `doxygen`.
4. Add a matrix row in `publish-docker.yml`.
5. Update this file and [`docker/readme.md`](../docker/readme.md).

## Further Reading

- [Architecture](architecture.md)
- [Presets](presets.md)
- [Contributing](contributing.md)
- [Docker BuildKit](https://docs.docker.com/build/buildkit/)
