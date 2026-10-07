---
description: Mechanical review of current diff (REVIEW.md + AGENTS.md, changed lines only)
agent: ct_cmake_review
---

Review `$ARGUMENTS` (default: `git diff HEAD --stat && git diff HEAD`).

```text
!`git diff HEAD --stat && git diff HEAD`
```

Apply `REVIEW.md` exactly, in order: lifetime/ownership, UB, init/narrowing, concurrency, error paths, interface impact, perf, style last.
- Changed lines only. No drive-by edits.
- Where rules conflict with nearby code, follow existing code and report the conflict.
- Ground C++ claims in cppreference; mark unverified `[unverified]`. Perf claims need measurements.
- Output: file:line list, each with rule + one-line fix. No pleasantries.
