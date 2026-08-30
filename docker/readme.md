# Docker Build Environment Reference

Reproducible **toolchain** images. Source is not baked in — mount repo at `/app`.

## Image matrix

| File | Base | Purpose | Architecture |
|------|------|---------|--------------|
| `fedora.Dockerfile` | Official `fedora:44` | Primary native validator | amd64, arm64 |
| `manjaro.Dockerfile` | `manjarolinux/base:latest` | Arch-family rolling validator | Upstream-dependent |
| `steamos.Dockerfile` | Valve Steam Runtime 4 SDK | Current Steam Linux ABI validation | amd64 |
| `cachyos.Dockerfile` | CachyOS official image | Optimized x86-64-v3 rolling validator | amd64; x86-64-v3 required |
| `alt.Dockerfile` | Docker Official Image `alt:p11` | Stable ALT compiler/tool validation | amd64, arm64 |
| `../nix/flake.nix` | nixpkgs `dockerTools` | Reproducible Nix dev shell and OCI image | amd64, arm64 |

SteamOS is appliance firmware, not a build sysroot. Valve recommends Steam Linux
Runtime 4 for new native Linux games, so the Steam image uses its official SDK.

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

# Current Steam ABI target.
docker build -t cmake-template:steamos -f docker/steamos.Dockerfile docker
docker run --rm -v "$PWD:/app" cmake-template:steamos

# Interactive shell.
docker run --rm -it -v "$PWD:/app" --entrypoint bash cmake-template:fedora
```

BuildKit is required for package-manager cache mounts.

## Nix usage

Nix lives under `nix/` with other environment definitions. One flake defines both
the interactive shell and OCI image, preventing package-list drift.

```bash
# Development shell.
nix develop ./nix
nix develop ./nix --command cmake --workflow --preset=gcc-full

# Build and load the OCI image.
nix build ./nix#docker
./result | docker load
docker run --rm -v "$PWD:/app" cmake-template-nix:latest
```

CI evaluates and builds the Nix image whenever `nix/**` changes. A committed lock
file can be added after generating it with Nix; CI currently resolves the selected
nixpkgs branch on each build instead of claiming a fixed dependency snapshot.

## Design

- Toolchain images only: no source snapshot and no runtime packaging.
- One image per distribution; compiler selection remains a CMake preset choice.
- BuildKit cache mounts persist package downloads.
- Default entrypoint: `cmake --workflow --preset=gcc-full`.
- GHCR publication includes provenance and SBOM attestations.
- Docker and Nix jobs run only when their respective files change.
