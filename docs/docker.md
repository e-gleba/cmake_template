## Docker

```bash
docker build -t cxx-skeleton -f docker/fedora.Dockerfile .
docker run --rm -v "$(pwd):/src" cxx-skeleton cmake --workflow --preset=gcc-full
```