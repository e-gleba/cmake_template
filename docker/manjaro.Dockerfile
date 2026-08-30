# syntax=docker/dockerfile:1
# Rolling Linux x86_64 toolchain validator.
# hadolint ignore=DL3007
FROM manjarolinux/base:latest
ARG SOURCE=""
LABEL org.opencontainers.image.title="cmake_template manjaro toolchain" \
      org.opencontainers.image.description="Rolling GCC + Clang + CMake + Ninja" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.licenses="MIT"
WORKDIR /app
RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
    pacman -Syu --noconfirm \
    && pacman -S --needed --noconfirm base-devel clang lld cmake ninja git doxygen graphviz pkgconf wayland libxkbcommon mesa \
    && pacman -Scc --noconfirm
ENTRYPOINT ["cmake", "--workflow", "--preset=linux_gcc_x86_64_release"]
