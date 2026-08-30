# syntax=docker/dockerfile:1
#
# Stable ALT Linux p11 toolchain validator.
# Source is not baked in — mount the repo at /app.

FROM alt:p11

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template ALT Linux toolchain" \
      org.opencontainers.image.description="ALT Linux p11 GCC + Clang + CMake + Ninja" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# ALT uses apt-rpm. Keep this image focused on portable build tools; native
# Wayland/EGL integration is already covered by Fedora and Arch-family images.
# hadolint ignore=DL3041
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get install -y \
        gcc-c++ \
        clang \
        cmake \
        ninja-build \
        git \
        pkg-config \
    && apt-get clean

ENTRYPOINT ["cmake", "--workflow", "--preset=gcc-full"]
