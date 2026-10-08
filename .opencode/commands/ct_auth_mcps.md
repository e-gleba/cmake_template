---
description: MCP token setup status (automatic via plugin, points at global .env)
agent: build
---

MCP token setup is automatic via `.opencode/plugins/ct_dotenv_auth.ts`; this command takes no arguments and only reports status.

Read `.opencode/ai-workflow-adapter.md` and apply its delegation and
text-handling rules.

Constraints (`AGENTS.md`): secrets live only in global
`~/.config/opencode/.env`, never in the repo; tokens never pass through
this session (never ask for a paste); `{env:}` resolves at startup, so
edits need an opencode restart; unclear = ask, not guess.

Token pages (mirrors the `KNOWN_TOKENS` table in `ct_dotenv_auth.ts`;
EDIT intranet rows to your instances):

| server | env var | token page |
|---|---|---|
| `ct_github` | `GITHUB_PERSONAL_ACCESS_TOKEN` | https://github.com/settings/tokens |
| `ct_teamcity` (example) | `CT_TEAMCITY_TOKEN` | https://teamcity.internal/profile.html |
| `ct_sentry` (example) | `CT_SENTRY_TOKEN` | https://sentry.internal/settings/auth-tokens/ |

Steps:

1. Status first, always visible: call the `ct_mcp_auth` plugin tool. All
   set → report and stop. This proves presence only — a wrong but
   non-empty key surfaces as an MCP 401 on first use, then continue below.
2. Human path, no AI needed, in the TUI: tell the user to run `/ct_auth`
   (native dialog from `.opencode/plugins/ct_auth_tui.ts`, one prompt per
   missing var) and restart opencode afterwards.
3. Human path outside the TUI: tell the user to run
   `.agents/scripts/auth/ct_auth_setup.sh` (POSIX) or `ct_auth_setup.ps1`
   (Windows) from the repo root. It prompts with masked input per missing
   var and writes global `~/.config/opencode/.env` (mode 600); empty input
   keeps the current value. Then restart opencode.
4. Fallback: the user opens `~/.config/opencode/.env` (auto-created 0600
   template) directly, fills the empty values from the token pages above,
   saves, and restarts opencode.
5. Tokens never pass through this session: never ask for a paste here,
   never accept one. Input lives only in the user's terminal or editor.

Failure ladder: file absent → the plugin recreates it on next start,
report the path; 401 after setup → the stored value is wrong, refill +
restart. One retry max, then report.

Report: server | env var | set/missing | follow-up done or pending.

Missing input: none — no arguments by design. If the user names a server
outside the table, ask through the native question tool whether to wire
it into `opencode.jsonc` + `KNOWN_TOKENS` first, then continue.
