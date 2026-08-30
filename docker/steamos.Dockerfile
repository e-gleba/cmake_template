# syntax=docker/dockerfile:1
#
# Steam Linux Runtime 4 SDK validator.
# Valve recommends steamrt4 for new native Linux games.
# Source is not baked in — mount the repo at /app.

FROM registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk:4.0.20260714.251823

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template Steam Runtime toolchain" \
      org.opencontainers.image.description="Valve Steam Linux Runtime 4 SDK" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

USER root
WORKDIR /app

# Valve's SDK supplies ABI-constrained compilers and sysroots.
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
