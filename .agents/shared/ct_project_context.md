# Compact project context

Keep continuity across tasks without loading history.

## Document roles

- `.opencode/AGENTS.md` is behavior: build, CMake, C++, presets, deps, tests, quality, CI, cross, packaging.
- `.opencode/REVIEW.md` is mechanical shape: what the review agent checks.
- `docs/references.md` owns links. No link duplication in readme or agent files.
- Current request + current source win. Older context never overrides them.

## Selective reading

Start from the request, then `.opencode/AGENTS.md`, then only the `cmake/presets/*.json`
or `cmake/toolchains/*.cmake` the request touches. Follow a dependency only
when the request makes it relevant. A link is not an instruction to load it.

For cross work, read the sibling preset (e.g. `linux.json` for a new Linux
variant) before inventing anything.
