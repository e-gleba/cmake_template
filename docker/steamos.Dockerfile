# syntax=docker/dockerfile:1
#
# Steam Linux Runtime 3 (sniper) SDK validator.
# Use Valve's SDK, not an unofficial SteamOS root filesystem: SteamOS is a
# gaming appliance OS, while this is the supported ABI target for Steam games.
#
# Source is not baked in — mount the repo at /app.

FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk:latest

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template Steam Runtime toolchain" \
      org.opencontainers.image.description="Valve Steam Runtime 3 (sniper) SDK" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

USER root
WORKDIR /app

# Valve's SDK supplies the ABI-constrained compiler and sysroot. Install only
# project-level tools missing from the SDK image.
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cmake \
        ninja-build \
        git \
        doxygen \
        graphviz \
        pkg-config

ENTRYPOINT ["cmake", "--workflow", "--preset=gcc-full"]
