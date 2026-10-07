---
description: Native configure + build + test loop (Debug default, one retry on failure)
agent: build
---

Run the native dev loop for `$ARGUMENTS` (default: `dev` preset, Debug config).
Do not invent presets or `cmake -D` lines.

Read `.opencode/ai-workflow-adapter.md` and apply its delegation and
text-handling rules.

Available configure presets:

```text
!`cmake --list-presets 2>/dev/null | head -30`
```

Steps:
1. `cmake --preset <preset>`, then `cmake --build --preset <preset>-debug -j`, then `ctest --preset <preset>-debug`.
2. On failure: read the first error, fix the single root cause, retry once.
   A second failure is a report, not another fix attempt.
3. Never fall back to Release to "just check". Never touch cross presets here.

Report (compact, no log dumps):
- preset, config, build OK/FAILED, tests passed/failed counts
- on failure: failing target + first error line + what the retry changed
