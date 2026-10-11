---
name: ct-auth
description: Fix MCP auth/runtime failures in ANY user language. MCP-only: use ONLY when an MCP tool errored or `opencode mcp list` shows a server failed (auth 400/401/403, bad header, missing {env:VAR}, OAuth, ENOENT, command not found, missing node/python). For plain git/gh CLI "authorize/login/token" (including Russian авторизуй/авторизация/войди/токен) with healthy MCP, do NOT use. Activates on MCP auth, bad header, missing env VAR, OAuth, ENOENT, missing node/python.
---

# ct-auth

MCP-only. Short replies. User's language always.

## 0. Triage (MCP or not)

Run `opencode mcp list`.
- All connected → STOP. Do not use this skill. Say MCP is healthy
  (in user's language) and handle the non-MCP auth directly.
- One failed + error matches §2/5/6 scope → continue below.
- Failed but unrelated to auth/runtime → STOP, report NAME + error,
  no env guesses.

## 1. Detect

Run `opencode mcp list`. Note failed `NAME` + error text.

## 2. Find VAR

Grep `{env:VAR}` under that `NAME` in `.opencode/opencode.jsonc`.
That `VAR` is the missing secret. If no `{env:...}` and the word
`oauth` (any case) appears anywhere in that `NAME` block, it is
OAuth — skip to 5. If neither, report NAME + error and stop.

Known VAR: `ct_github` → `GITHUB_PERSONAL_ACCESS_TOKEN`
(get it at https://github.com/settings/tokens).
Unknown server → token page of that provider.

## 3. Tell user (then STOP)

Reply in the user's language, exactly this shape:

- where to get the token (URL)
- one command for the USER to run (you never run it, never touch secrets):

`opencode service set env VAR "paste-token-here"`

- one line: "paste the command in your terminal, then write done/try again".

Never ask for the secret. Never print secrets. Never use another
binary — `opencode` from PATH is the current exe.
Ask via native question tool only when blocked (several servers failed
and unclear which is first; both `{env:VAR}` and `oauth` markers present
so env vs OAuth unclear; retry gave neither done nor new error). One
question max per turn, 2-4 grounded options + free text. Never ask what
is already known (NAME, VAR, command).

## 4. Retry (only after user writes done / try again)

1. `opencode service restart`
2. `opencode mcp list`
3. `NAME` connected → resume the original task silently.
   Still failed → steps 2–4 one more time max (two attempts total),
   then stop and report 3 lines: NAME / error / VAR.

## 5. OAuth instead of env

If step 2 found OAuth: tell the user to run
`opencode mcp auth NAME` in their terminal, then write done.
Retry per step 4 (restart included).

## 6. Missing runtime (node/python)

Trigger: error mentions `command not found`, `ENOENT`, or missing
`node`/`npx`/`python3`. Reply in the user's language, exactly this:

- run in repo root (project-local, no global change, all OSes):
  `mise use node@lts python@3.12 && mise install`
- no mise: python via `uv python install`, node via `fnm install --lts`.
  If neither tool exists → stop and report NAME / error / missing runtime.
- then write done. Retry per step 4.
