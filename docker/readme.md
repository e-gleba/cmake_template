# Docker Build Environments

Toolchain images. Mount repository at `/app`; source is not embedded.

## Usage

```bash
docker build -t cmake-template:fedora -f docker/fedora.Dockerfile docker
docker run --rm -v "$PWD:/app" cmake-template:fedora
```

Default workflow: `linux_gcc_x86_64_release`.

## Images

- `fedora.Dockerfile`: stable Fedora native Linux x86_64 validator
- `manjaro.Dockerfile`: rolling Manjaro native Linux x86_64 validator
- `steamos.Dockerfile`: Steam Linux Runtime 4 x86_64 validator
- `cachyos.Dockerfile`: CachyOS x86_64-v3 validator
- `alt.Dockerfile`: ALT Linux p11 native Linux x86_64 validator
- `../nix/flake.nix`: Nix development shell and OCI image

CI lints and builds only changed Dockerfiles.
