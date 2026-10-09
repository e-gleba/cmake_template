---
name: ct-auth
description: Provision or rotate {env:} API secrets for MCP servers via masked OS prompt. Use when an MCP call fails with 401/unauthorized, an {env:VAR} value is missing or invalid, or the user says "auth me" or asks to connect a service.
compatibility: opencode
---

# ct-auth

Provision MCP secrets. Values enter only via masked prompter, never via chat.

1. Discover: `grep -rho '{env:[A-Za-z_][A-Za-z0-9_]*}' .opencode/opencode.jsonc ~/.config/opencode/opencode.json | sort -u`.
2. Status: `python3 .agents/skills/ct-auth/scripts/mcp_env_set.py VAR --check` per VAR.
3. Ask via question tool (`multiple: true`):
   - Missing VARs -> select which to fill.
   - Set VAR with explicit user request or MCP 401 -> confirm `Overwrite` vs `Keep`. Never overwrite without confirmation. All set, no request, no 401 -> stop, report set.
   - Token-page URL as free text for `--url`, never the token itself.
4. Act per confirmed VAR: `python3 .agents/skills/ct-auth/scripts/mcp_env_set.py <VAR> --launch --url <token-page> --instructions "<what-to-do>"` (wait for close, 5-min input timeout). `--instructions` REQUIRED: 1-3 lines, which token to create + URL as plain text (auto-open fails on some OS). TTY -> inline prompt; desktop -> one window; headless (exit 2) -> hand user the printed manual command. Never hand-roll terminals.
5. Verify by exit code + script result line only. Shell picks up `ct_project.env` live via `ct_project_env` plugin automatically (no restart); remote MCP `{env:}` substitutes at config load -> start a new session / reconnect MCP (full restart if it still uses the old value) before retry.
