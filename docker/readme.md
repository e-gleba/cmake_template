# Docker Build Environment Reference

Reproducible **toolchain** images. Source is not baked in — mount the repo at `/app`.

## Files

| File | Purpose |
|------|---------|
| `fedora.Dockerfile` | Primary image. Official `fedora:44`. Recommended default. |
| `manjaro.Dockerfile` | Rolling validator. Official `manjarolinux/base:latest`. |
| `.dockerignore` | Context is this directory — only the Dockerfiles ship. |

## Usage

Full guide: [`docs/docker.md`](../docs/docker.md).

```bash
# Build (context = this directory)
docker build -t cmake-template:fedora -f fedora.Dockerfile .
docker build -t cmake-template:manjaro -f manjaro.Dockerfile .

# Full workflow (mount project root)
docker run --rm -v "$(pwd)/..:/app" cmake-template:fedora

# Interactive shell
docker run --rm -it -v "$(pwd)/..:/app" --entrypoint bash cmake-template:fedora
```

> BuildKit required (`DOCKER_BUILDKIT=1`) for cache mounts.

## Design

- Single stage. Toolchain only — not a runtime image, not a source snapshot.
- BuildKit cache mounts persist `dnf` / `pacman` caches.
- `ENTRYPOINT` is `cmake --workflow --preset=gcc-full`.
- Published to GHCR by [`.github/workflows/publish-docker.yml`](../.github/workflows/publish-docker.yml). Add a matrix row to ship another image.

## Contributing

1. Image builds with `docker build --no-cache`.
2. Full workflow: `docker run --rm -v "$(pwd)/..:/app" <image>`.
3. Update `docs/docker.md` if images or usage change.

See [`docs/contributing.md`](../docs/contributing.md).
