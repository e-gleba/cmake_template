---
name: steam-runtime
description: Use when working on steam presets, cmake/steampipe/, or runtime compatibility.
---
1. Build in the SDK image. Unit tests may run in the SDK, but runtime compatibility — library resolution and execution — must be validated in the Platform image: the SDK ships extra libs that mask missing deps.
2. New system-library find_package under a steam preset → use pkg_check_modules(... IMPORTED_TARGET), never raw variables.
3. Windows steam builds: static CRT only. Gate: cmake/steampipe/check_pe_imports.cmake — vcruntime140.dll/msvcp140.dll = fail.
4. Steam IDs are CT_STEAM_* cache variables; VDFs + steam_appid.txt are generated into the gitignored build tree — never commit a real App ID.
