# syntax=docker/dockerfile:1
#
# Stable ALT Linux p11 toolchain validator.
# Source is not baked in — mount the repo at /app.

FROM alt:p11

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template ALT Linux toolchain" \
      org.opencontainers.image.description="ALT Linux p11 GCC + Clang + CMake" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# ALT uses apt-rpm, names pkg-config as pkgconf, and does not implement
# Debian's --no-install-recommends option. Versions follow the p11 platform.
# hadolint ignore=DL3008,DL3015
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get install -y \
        gcc-c++ \
        clang \
        cmake \
        git \
        make \
        pkgconf \
    && rm -rf /var/cache/apt /var/lib/apt/lists

ENTRYPOINT ["cmake", "--workflow", "--preset=gcc-full"]
