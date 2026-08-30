# syntax=docker/dockerfile:1
#
# Toolchain image for native Linux builds (gcc / clang / ninja / cmake).
# Source is not baked in — mount the repo at /app.
#
#   docker build -t cmake-template:fedora -f docker/fedora.Dockerfile docker
#   docker run --rm -v "$PWD:/app" -w /app cmake-template:fedora \
#     cmake --workflow --preset=linux_gcc_x86_64_release_package

# Pin the current stable. Dependabot / Renovate bump this tag.
FROM fedora:44

ARG SOURCE=""

LABEL org.opencontainers.image.title="cmake_template fedora toolchain" \
      org.opencontainers.image.description="GCC + Clang + CMake 3.31+ + Ninja" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Distro packages track the image tag (fedora:44). Pinning each RPM
# would fight Dependabot and add no reproducibility here.
# hadolint ignore=DL3041
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y upgrade --refresh \
    && dnf -y install \
        gcc-c++ \
        clang \
        clang-tools-extra \
        lld \
        cmake \
        ninja-build \
        git \
        doxygen \
        graphviz \
        pkgconf-pkg-config \
        wayland-devel \
        libxkbcommon-devel \
        mesa-libEGL-devel \
    && dnf clean all

# Override: docker run --entrypoint bash … for a shell.
ENTRYPOINT ["cmake", "--workflow", "--preset=linux_gcc_x86_64_release_package"]
