# Docker Build Environment Reference

Reproducible **toolchain** images. Source is not baked in — mount repo at `/app`.

## Image matrix

| File | Base | Purpose | Architecture |
|------|------|---------|--------------|
| `fedora.Dockerfile` | Official `fedora:44` | Primary, stable native validator | amd64, arm64 |
| `manjaro.Dockerfile` | `manjarolinux/base:latest` | General Arch-family rolling validator | amd64, arm64 where upstream provides it |
| `steamos.Dockerfile` | Valve Steam Runtime 3 SDK | Steam/Steam Deck ABI validation | amd64 |
| `cachyos.Dockerfile` | CachyOS official image | Optimized x86-64-v3 rolling validator | amd64 (x86-64-v3 CPU required) |
| `alt.Dockerfile` | Docker Official Image `alt:p11` | Stable ALT Linux platform validation | amd64, arm64 |
| `.dockerignore` | — | Keeps build context minimal | — |

SteamOS itself is immutable appliance firmware, not a supported build sysroot. The
Steam image therefore uses Valve's official Steam Runtime SDK: this validates the
ABI users actually run through Steam and avoids depending on unofficial SteamOS
root filesystems.

Alpine and Wolfi are intentionally omitted. Both use musl; this template's native
Wayland/EGL stack and Android/glibc assumptions make them poor representative
validators. Manjaro and CachyOS already cover minimal rolling/Arch-family needs.

## Usage

```bash
# Run from repository root.
docker build -t cmake-template:fedora -f docker/fedora.Dockerfile docker
docker run --rm -v "$PWD:/app" cmake-template:fedora

# Choose another validator.
docker build -t cmake-template:steamos -f docker/steamos.Dockerfile docker
docker run --rm -v "$PWD:/app" cmake-template:steamos

# Interactive shell.
docker run --rm -it -v "$PWD:/app" --entrypoint bash cmake-template:fedora
```

BuildKit is required for package-manager cache mounts.

## NixOS / nixpkgs

Nix support is a native flake rather than a Dockerfile. This preserves nixpkgs'
compiler wrappers and dependency environment instead of flattening them into a
mutable image.

```bash
nix develop
cmake --workflow --preset=gcc-full

# One-shot CI/local check.
nix develop --command cmake --workflow --preset=gcc-full
```

`flake.lock` should be generated and committed by a Nix-enabled contributor before
reproducible Nix CI is made required. Until then, `nixos-unstable` supplies current
toolchains but is not bit-for-bit pinned.

## Design

- Toolchain images only: no source snapshot and no runtime packaging.
- One image per distribution; compiler choice remains a CMake preset/runtime choice.
- BuildKit cache mounts persist package downloads.
- Default `ENTRYPOINT`: `cmake --workflow --preset=gcc-full`.
- GHCR publication includes provenance and SBOM attestations.
- Docker CI runs only when Docker or its workflow changes.

## Contributing

1. Build affected image with `docker build --no-cache`.
2. Mount repository root and run its default workflow.
3. Update this matrix when adding/removing images.
