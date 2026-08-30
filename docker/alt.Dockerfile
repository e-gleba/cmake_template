# syntax=docker/dockerfile:1
# Stable ALT Linux p11 x86_64 toolchain validator.
FROM alt:p11
ARG SOURCE=""
LABEL org.opencontainers.image.title="cmake_template ALT Linux toolchain" \
      org.opencontainers.image.description="ALT Linux p11 GCC + Clang + CMake" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"
WORKDIR /app
# hadolint ignore=DL3008,DL3015
RUN mkdir -p /var/cache/apt/archives/partial /var/lib/apt/lists/partial \
    && apt-get update \
    && apt-get install -y gcc-c++ clang cmake git make pkgconf \
    && rm -rf /var/cache/apt /var/lib/apt/lists
ENTRYPOINT ["cmake", "--workflow", "--preset=linux_gcc_x86_64_release"]
