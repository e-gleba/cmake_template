# Docker Build Environment Reference

Reproducible **toolchain** images. Source is not baked in — mount repo at `/app`.

## Image matrix

| File | Base | Purpose | Architecture |
|------|------|---------|--------------|
| `fedora.Dockerfile` | Official `fedora:44` | Primary native validator | amd64, arm64 |
| `alt.Dockerfile` | Docker Official Image `alt:p11` | Stable ALT compiler/tool validation | amd64, arm64 |

ALT p11 does not package Ninja under the expected cross-distro name. Its validator
uses Make while all other images exercise Ninja. This keeps ALT coverage native
instead of downloading an unrelated tool binary.

Alpine and Wolfi are intentionally omitted. Their musl ABI would add divergence
without improving coverage for this glibc/Wayland/Android-oriented template.

## Docker usage

```bash
# Run from repository root.
docker build -t cmake-template:fedora -f docker/fedora.Dockerfile docker
docker run --rm -v "$PWD:/app" cmake-template:fedora

# Interactive shell.
docker run --rm -it -v "$PWD:/app" --entrypoint bash cmake-template:fedora
```

BuildKit is required for package-manager cache mounts.

## Design

- Toolchain images only: no source snapshot and no runtime packaging.
- One image per distribution; compiler selection remains a CMake preset choice.
- BuildKit cache mounts persist package downloads.
- Default entrypoint: `cmake --workflow --preset=linux_gcc_x86_64_release_package`.
- GHCR publication includes provenance and SBOM attestations.
- Docker jobs are manual only: dispatch `docker_ci` (build + verify) or
  `docker_publish` (push to GHCR) from Actions, the release workflow input,
  or the readme ▶ buttons.
