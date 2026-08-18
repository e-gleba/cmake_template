# syntax=docker/dockerfile:1
#
# Rolling-release validator (Arch/Manjaro). Bleeding-edge GCC/Clang.
# Source is not baked in — mount the repo at /app.
#
#   docker build -t cmake-template:manjaro -f docker/manjaro.Dockerfile docker
#   docker run --rm -v "$PWD:/app" -w /app cmake-template:manjaro \
#     cmake --workflow --preset=gcc-full

# latest is the point of a rolling validator. Dependabot still watches it.
# hadolint ignore=DL3007
FROM manjarolinux/base:latest

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template manjaro toolchain" \
      org.opencontainers.image.description="Rolling GCC + Clang + CMake + Ninja" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# base-devel = gcc, make, glibc headers. Cache mount for pacman pkgs.
# https://docs.docker.com/build/cache/optimize/#use-cache-mounts
RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
    pacman -Syu --noconfirm \
    && pacman -S --needed --noconfirm \
        base-devel \
        clang \
        lld \
        cmake \
        ninja \
        git \
        doxygen \
        graphviz \
        pkgconf \
        wayland \
        libxkbcommon \
        mesa \
    && pacman -Scc --noconfirm

ENTRYPOINT ["cmake", "--workflow", "--preset=gcc-full"]
