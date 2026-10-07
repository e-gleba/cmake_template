---
description: Native dev build + test (configure, build, test in one go)
agent: build
---

Run the native dev loop. Do not invent presets.

```text
$ARGUMENTS
```

Steps:
1. `cmake --preset dev && cmake --build --preset dev -j && ctest --preset dev`
2. If configure fails, read `cmake/presets/*.json` and report the exact missing preset — never guess a `cmake -D` command line.
3. Report: configured preset, build target, test result. Keep output short.

Rules from AGENTS.md apply: targets only, no global flags, explicit sources.
