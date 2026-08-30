# syntax=docker/dockerfile:1
#
# Stable ALT Linux p11 validator using the Docker Official Image.
# Source is not baked in — mount the repo at /app.

FROM alt:p11

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template ALT Linux toolchain" \
      org.opencontainers.image.description="ALT Linux p11 GCC + Clang + CMake + Ninja" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# ALT uses apt-rpm. Package versions follow the pinned p11 platform.
# hadolint ignore=DL3041
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y \
        gcc-c++ \
        clang \
        lld \
        cmake \
        ninja-build \
        git \
        doxygen \
        graphviz \
        pkg-config \
        libwayland-devel \
        libxkbcommon-devel \
        libEGL-devel \
    && apt-get clean

ENTRYPOINT ["cmake", "--workflow", "--preset=gcc-full"]
