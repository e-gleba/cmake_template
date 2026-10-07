---
description: One-time token setup for key-based MCP servers (status, ask, paste, persist)
agent: build
---

Set up MCP tokens. This command takes no arguments — it asks.

Read `.opencode/ai-workflow-adapter.md` and apply its delegation and
text-handling rules.

Server table (env names are `CT_`-prefixed to avoid collisions — every new
key server gets a `CT_` name matching its `{env:}` placeholder in
`.opencode/opencode.jsonc`; EDIT intranet rows to your instances):

| server | env var | token page | create |
|---|---|---|---|
| `ct_github` | `CT_GITHUB_PAT` | https://github.com/settings/tokens | classic PAT, `read` scopes per the install guide linked in `opencode.jsonc` |
| `ct_teamcity` | `CT_TEAMCITY_TOKEN` | https://teamcity.internal/profile.html | TeamCity access token for your user |
| `ct_sentry` | `CT_SENTRY_TOKEN` | https://sentry.internal/settings/auth-tokens/ | Sentry auth token (org access) |

Steps:
1. Status first, always visible: for each env var above, run
   `mcp_env_set.py VAR --check`. All set → report and stop. This proves
   presence only — a wrong but non-empty key surfaces as an MCP 401 on
   first use, then rerun this.
2. Ask through the native question tool (`multiple: true`): one option
   per missing server, labeled `server — what to create + token page`.
   Nothing selected → stop.
3. Per selected server, one at a time with `[1/2] …` progress. One call
   carries everything (table → argv, server knowledge never hardcoded):
   `python3 .opencode/scripts/mcp_env_set.py <VAR> --launch --url '<token-page>'`
   `--info 'Create: <create text>\nNeeds: <perms/scope>'`
   with a 5-minute timeout; wait for the process to close. TTY/display
   checks live in the script (env + `PATH` only, never probe windows):
   TTY → prompts inline, zero windows; no TTY + display → `--launch`
   self-opens exactly one titled prompt window; no TTY and no display →
   prints the manual command and opens nothing. Never open probe/test
   windows (`echo hello`, `sleep`, `tee` wrappers, bare `konsole -e`
   trials are banned), never hand-roll `konsole -e` / `gnome-terminal`
   / `xterm` — the script owns the single launch, and never grep env
   or rc files to verify. Judge by exit code plus the script's own
   result line: 0 → saved; 2 → manual command printed, opens nothing
   (hand it to the user); anything else → reason already printed,
   rerun to retry.
   c. Tokens never pass through this session: never ask for a paste
      here, never accept one, never pipe one through shell. Input lives
      only inside the script's masked prompt (`***` echo, 5-minute limit,
      window closes itself).
4. After persisting: follow the script's printed next step (`source <rc>`
   on POSIX, restart captures `setx` on Windows) and restart opencode —
   `{env:}` resolves at startup, a running session never picks up new
   exports.

Report: server | env var | exit code + result (saved / failed / manual) | follow-up done or pending.
