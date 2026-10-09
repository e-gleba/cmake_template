---
description: Cut a release — changelog entry from git log, version bump, single commit
agent: build
---

Release `$ARGUMENTS`. If empty, auto-increment the patch as stable; `beta` marks it beta, an explicit `X.Y[.Z]` overrides the number.

Read `.opencode/ai-workflow-adapter.md` and apply its delegation and
text-handling rules. Constraints from `.opencode/AGENTS.md` (non-negotiable):

- Version truth is `project(VERSION)` in root `CMakeLists.txt`; tags are `v<version>`.
- `git status --porcelain` must be clean before starting — otherwise stop.
- Never edit past changelog entries; prepend only, 4-12 user-facing bullets.

```text
!`git status --short && git tag --sort=-v:refname | head -5 && grep -n "project(" CMakeLists.txt | head -5`
```

Steps:
1. Resolve the version (explicit arg wins, else patch+1; a beta never reuses a stable number). Confirm it via the native question tool before writing anything.
2. Collect `git log <last-tag>..HEAD --oneline`; draft bullets — imperative, ~80 chars, user-facing only (skip CI/infra/refactors), features first, then fixes.
3. Prepend the entry (`<version> [beta ](DD.MM.YY)` + bullets) to `docs/CHANGELOG.md`; bump `project(VERSION)` to match. Get entry approval via the question tool — do not proceed until approved.
4. Commit once (`Version X.Y[.Z].` / `Beta version X.Y.Z.` + bullets wrapped at 72 cols); show `git log -1`.

Failure ladder: dirty tree, ambiguous version, or failed configure after the bump = stop and report, no commit.
Report: version, changelog path, commit sha, bullet count. No log dumps.
