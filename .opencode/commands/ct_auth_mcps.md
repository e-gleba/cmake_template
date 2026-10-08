---
description: One-time token setup for key-based MCP servers (status, ask, paste, persist)
agent: build
---

Set up MCP tokens. This command takes no arguments — it asks.

Read `.opencode/ai-workflow-adapter.md` and apply its delegation and
text-handling rules.

Server table (env names must match the `{env:}` placeholders in
`.opencode/opencode.jsonc`; EDIT intranet rows to your instances):

| server | env var | token page | create |
|---|---|---|---|
| `ct_github` | `GITHUB_PERSONAL_ACCESS_TOKEN` | https://github.com/settings/tokens | classic PAT, `read` scopes per the install guide linked in `opencode.jsonc` |
| `ct_teamcity` | `CT_TEAMCITY_TOKEN` | https://teamcity.internal/profile.html | TeamCity access token for your user |
| `ct_sentry` | `CT_SENTRY_TOKEN` | https://sentry.internal/settings/auth-tokens/ | Sentry auth token (org access) |

Steps:
1. Status first, always visible: for each env var above, test
   `[ -n "$VAR" ] && echo set` (or `mcp_env_set.py VAR --check`).
   All set → report and stop. This proves presence only — a wrong but
   non-empty key surfaces as an MCP 401 on first use, then rerun this.
2. Ask through the native question tool (`multiple: true`): one option
   per missing server, labeled `server — what to create + token page`.
   Nothing selected → stop.
3. Per selected server, one at a time with `[1/2] …` progress. One call
   carries everything (table → argv, server knowledge never hardcoded):
   `python3 .opencode/scripts/mcp_env_set.py <VAR> --url '<token-page>'`
   `--info 'Create: <create text>\nNeeds: <perms/scope>'`
   with a 5-minute timeout; wait for the process to close. The script
   opens the page, prints the instructions inside the window, then
   prompts masked. Prefer a titled prompt window when this shell has no
   TTY but a display does: `konsole -e …` (fallbacks: `gnome-terminal
   --`, `xterm -e`). No TTY and no display → hand the exact command to
   the user instead.
   c. Tokens never pass through this session: never ask for a paste
      here, never accept one, never pipe one through shell. Input lives
      only inside the script's masked prompt (`***` echo, 5-minute limit,
      window closes itself).
4. After persisting: follow the script's printed next step (`source <rc>`
   on POSIX, restart captures `setx` on Windows) and restart opencode —
   `{env:}` resolves at startup, a running session never picks up new
   exports.

Report: server | env var | set/persisted | follow-up done or pending.
