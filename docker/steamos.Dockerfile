# syntax=docker/dockerfile:1
FROM registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk:4.0.20260714.251823
ARG SOURCE=""
LABEL org.opencontainers.image.title="cmake_template Steam Runtime toolchain" \
      org.opencontainers.image.description="Valve Steam Linux Runtime 4 SDK" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"
USER root
WORKDIR /app
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates cmake ninja-build git doxygen graphviz pkg-config
USER 1000
ENTRYPOINT ["cmake", "--workflow", "--preset=linux_gcc_x86_64_release_package"]
