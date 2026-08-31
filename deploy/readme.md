# Steam & Steam Deck deployment

Build, verify, and package this project for Steam — with proof that the
binaries run inside Valve's own Steam Runtime, the same environment games
get on Steam Deck and desktop Linux.

## Two ways onto Steam Deck

| Strategy | What you ship | Runtime on Deck / Linux | When to use |
| --- | --- | --- | --- |
| **Native Linux** | ELF binary | Steam Linux Runtime 4.0 (`steamrt4`) container | Best performance; Valve's recommended target for new native games |
| **Windows via Proton** | Windows `.exe` | Proton 11+ (itself runs inside a steamrt4 container) | One Windows build covers Windows + Deck |

Both are verified in CI. Native Linux builds use the
`linux_steamrt4_x86_64` preset; Windows builds use the static-CRT
`windows_*_steam_x86_64` presets.

## Presets

| Preset | Host | What it enforces |
| --- | --- | --- |
| `linux_steamrt4_x86_64` | steamrt4 SDK container | GCC from the SDK, IPO/LTO; the SDK sysroot caps the ABI at the runtime baseline |
| `windows_msvc_steam_x86_64` | Windows | `/MT` static CRT via `CMAKE_MSVC_RUNTIME_LIBRARY` — no VC++ redist needed |
| `windows_llvm_mingw_steam_x86_64` | Linux (cross) | `-static-libgcc -static-libstdc++ -static` — the `.exe` imports only Windows system DLLs |

Each has a `*_release_package` workflow preset producing a ZIP that maps
directly onto a SteamPipe depot `contentroot`.

## What CI verifies (`steam_runtime_ci`)

### 1. Build inside the steamrt4 SDK image

`registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk` — Valve's toolchain
with compilers and headers constrained to the runtime ABI. Building here
makes glibc/libstdc++ version creep impossible by construction.

### 2. ABI gate (`scripts/steam/check_elf_abi.sh`)

For every produced ELF binary:

- **Resolution** — `ldd` must resolve every `NEEDED` entry; the log shows
  the exact path each library is taken from.
- **Symbol versions** — every `GLIBC_*` / `GLIBCXX_*` / `CXXABI_*` /
  `GCC_*` version tag the binary imports must exist in the runtime's own
  `libc.so.6` / `libstdc++.so.6` / `libgcc_s.so.1`. Nothing is hardcoded:
  the runtime under test is the baseline.

### 3. Platform smoke test

The SDK image ships extra dev libraries that can mask a missing runtime
dependency — so the produced binaries are also validated inside
`registry.gitlab.steamos.cloud/steamrt/steamrt4/platform`, the minimal
client-identical runtime that actually ships to users:

- **Resolution gate** — the dynamic loader itself (`ld-linux --list`)
  prints which runtime path every `NEEDED` library of every shipped
  binary is taken from; any `not found` fails the job. This also covers
  `02_sdl3_app`: it needs a display to execute, but only the loader to
  validate. The staged `libSDL3.so.0` is provided via `LD_LIBRARY_PATH`.
- **Execution** — `01_hello_world` (with `LD_DEBUG=libs`, so the loader
  traces its own resolution) and the full doctest suite run for real.

This is the same container technology Steam Deck uses: SLR 4.0 runs native
Linux games, and Proton 11+ runs Windows games inside steamrt4.

### 4. Static CRT gates (Windows)

- MSVC: `scripts/steam/check_pe_imports.ps1` (dumpbin) fails if any binary
  imports `vcruntime140*.dll`, `msvcp140*.dll`, `concrt140.dll`, or
  `vccorlib140.dll`.
- LLVM-MinGW: `scripts/steam/check_pe_imports.sh` fails on any MinGW
  runtime DLL (`libstdc++-6.dll`, `libc++.dll`, `libgcc_s_*.dll`,
  `libwinpthread-1.dll`, `libunwind.dll`) and on the MSVC redist names.

Both scripts carry their denylist as a default — pass `-Forbidden` / a
`--` argument list to override.

`ucrtbase.dll` is fine: it is a Windows 10+ system component, not a
redistributable.

## Reproduce locally

```bash
# Build inside the steamrt4 SDK (same image as CI)
docker run --rm -it -v "$PWD:/src" -w /src \
  registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk:4.0.20260805.254769 \
  bash -c "cmake --workflow --preset linux_steamrt4_x86_64_release_package"

# ABI gate
bash scripts/steam/check_elf_abi.sh build/linux_steamrt4_x86_64/src

# Execute in the client-identical platform runtime
docker run --rm -v "$PWD/build/linux_steamrt4_x86_64:/opt/app:ro" \
  registry.gitlab.steamos.cloud/steamrt/steamrt4/platform:4.0.20260805.254769 \
  /opt/app/src/01_hello_world/Release/01_hello_world
```

## Adding system libraries under the steam preset

Autotools-built libraries inside the Steam Runtime (ogg, vorbis, ...) ship
**no CMake config files** — `find_package(Ogg)` fails even though the
library is installed. Use pkg-config with imported targets instead:

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(OGG REQUIRED IMPORTED_TARGET ogg)
target_link_libraries(your_target PRIVATE PkgConfig::OGG)
```

`IMPORTED_TARGET` is essential — raw `OGG_LIBRARIES` variables produce
broken link lines. Dependencies fetched via CPM (SDL3, doctest, ...) are
unaffected: they build from source inside the SDK.

The SDK's apt repositories are preconfigured — install extra `-dev`
packages with apt rather than vendoring them.

## Uploading to Steam (SteamPipe)

```
deploy/
├── steam_appid.txt.example   # copy to steam_appid.txt, put your real App ID in it
├── app_build.vdf             # SteamPipe app script
├── depot_windows_x86_64.vdf  # Windows depot mapping
└── depot_linux_x86_64.vdf    # Linux depot mapping
```

1. Copy `steam_appid.txt.example` to `steam_appid.txt` and replace `480`
   (Spacewar, Valve's test app) with your real App ID.
   `deploy/steam_appid.txt` is gitignored — never commit a real ID.
2. Create depots in Steamworks (App Admin → Depots) and put their IDs into
   the `depot_*.vdf` files AND the `depots` block of `app_build.vdf` — the
   app manifest maps depot IDs to depot scripts, so both must match.
3. Stage depot content: unzip the CI `steam-depot-*` artifacts (or local
   `*_release_package` ZIPs) into `build/steam/content/<platform>/` (the
   `build/` root is gitignored).
4. Upload:

```bash
steamcmd +login <steam_user> \
  +run_app_build /path/to/deploy/app_build.vdf \
  +quit
```

`app_build.vdf` ships with `"preview" "1"` (dry run) — set it to `"0"`
for a real upload, and set `setlive` to a branch name to publish.

## Steam Deck Verified notes

The build-side requirements are covered by CI above. The remaining
Verified criteria are game-side: 1280x800 default resolution, full
controller support with Steam Input glyphs, readable text, and no
launcher. See the official checklist:
<https://partner.steamgames.com/doc/steamdeck/verified>

For on-device validation: install "Steam Linux Runtime 4.0"
(`steam://install/4183110`) on the Deck, then either add the binary as a
non-Steam game and force the SLR 4.0 compatibility tool, or copy the build
over and run it in Desktop Mode inside the runtime.

## Targeting SLR 3.0 (sniper) instead

Sniper is the older runtime (Proton 8–10). If you must target it, mirror
this setup with `registry.gitlab.steamos.cloud/steamrt/sniper/sdk` and
`.../sniper/platform` — the presets and gates are runtime-agnostic.

## References

- [ValveSoftware/steam-runtime](https://github.com/ValveSoftware/steam-runtime) — runtime overview, SDK docs, apt repos
- [Steam Runtime 4 SDK](https://gitlab.steamos.cloud/steamrt/steamrt4/sdk) — the SDK image used here
- [Steamworks: uploading builds (SteamPipe)](https://partner.steamgames.com/doc/sdk/uploading)
- [Steam Deck Verified](https://partner.steamgames.com/doc/steamdeck/verified)
- [MSVC /MT vs /MD](https://learn.microsoft.com/en-us/cpp/build/reference/md-mt-ld-use-run-time-library)
- [GCC link options](https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html)
