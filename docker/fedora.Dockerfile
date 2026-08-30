# syntax=docker/dockerfile:1
# Toolchain image for native Linux x86_64 builds.
FROM fedora:44
ARG SOURCE=""
LABEL org.opencontainers.image.title="cmake_template fedora toolchain" \
      org.opencontainers.image.description="GCC + Clang + CMake + Ninja" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"
WORKDIR /app
# hadolint ignore=DL3041
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y upgrade --refresh \
    && dnf -y install gcc-c++ clang clang-tools-extra lld cmake ninja-build git doxygen graphviz pkgconf-pkg-config wayland-devel libxkbcommon-devel mesa-libEGL-devel \
    && dnf clean all
ENTRYPOINT ["cmake", "--workflow", "--preset=linux_gcc_x86_64_release"]
