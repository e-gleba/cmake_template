# syntax=docker/dockerfile:1
#
# CachyOS rolling-release validator. Requires x86-64-v3; it is intentionally
# excluded from multi-architecture publishing.
# Source is not baked in — mount the repo at /app.

FROM cachyos/cachyos:latest

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template CachyOS toolchain" \
      org.opencontainers.image.description="CachyOS x86-64-v3 GCC + Clang + CMake + Ninja" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

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
