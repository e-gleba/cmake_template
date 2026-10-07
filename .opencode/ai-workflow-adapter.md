# opencode AI Workflow Adapter

Read this file only when a command or agent explicitly loads it.
`AGENTS.md` owns behavior, `REVIEW.md` owns mechanical shape,
`.agents/shared/ct_test_loop.md` owns the build/test loop.
This file adapts harness mechanics to opencode and removes nothing else.

## Delegation

- opencode commands run in the current session; they never spawn child
  sessions. A command frontmatter `agent:` only switches the session agent.
- Use the `subagent` tool (foreground) for the single read-only review pass:
  `@ct_cmake_review` over the diff. One call, then validate its report
  in-session. Never chain subagents; `subagent_depth` stays default (1).
- Give every subagent a self-contained prompt (exact files, diff, and
  `REVIEW.md` sections). It inherits no parent context.
- A long native build (`cmake --build`) may run as a background shell;
  opencode notifies on exit — never poll it with `sleep` loops.
- Never launch a nested `opencode` process from Bash; use the `subagent`
  tool or `@`-mention instead.

## Text handling

- Keep LF-only, UTF-8 without BOM (see `AGENTS.md` ## Text files).
- Do not run line-ending normalization, BOM repair, or dedicated text
  phases. Normal editing preserves the checkout convention.
- Never rewrite a file solely to change line endings.

## Presets and tests

- Follow `.agents/shared/ct_test_loop.md` exactly: native presets get
  configure + build + `ctest`; cross presets (`android_*`,
  `windows_llvm_mingw_*`, `web_*`) get configure only, no `ctest`.
- Never invent `cmake -D` command lines. Read `CMakePresets.json` plus
  `cmake/presets/*.json`; report a missing preset instead of guessing.
- Never build Release just to check. Debug is the test config.

## Review

- `/ct_review` is the only review entry point: diff in, `REVIEW.md`
  procedure out, via `@ct_cmake_review` (read-only, `edit: deny`).
- Changed lines only. No drive-by edits. Conflicts with nearby code resolve
  toward existing code, reported — never silently rewritten.

## Commits

- Apply the `## Commits` `[ai] ` rule per commit: prefix only when every
  retained change is AI workflow (`AGENTS.md`, `REVIEW.md`, `.opencode/`,
  `.agents/`, commands/agents). Mixed commits take no prefix.
- Never add `Co-Authored-By`, tool attribution, or run-marker trailers.
