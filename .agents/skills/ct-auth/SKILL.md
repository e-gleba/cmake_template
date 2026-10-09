---
name: ct-auth
description: Provision missing {env:} API secrets for MCP servers via masked OS prompt. Use when an MCP call fails with 401/unauthorized, an {env:VAR} value is missing or invalid, or the user says "auth me" or asks to connect a service.
compatibility: opencode
---

# ct-auth

Secrets enter only through the masked prompter — values never touch the session.

1. Discover: `grep -rho '{env:[A-Za-z_][A-Za-z0-9_]*}' .opencode/opencode.jsonc ~/.config/opencode/opencode.json | sort -u`.
2. Status: `python3 .agents/skills/ct-auth/scripts/mcp_env_set.py VAR --check` each. All set → stop (wrong-but-set key shows as MCP 401; rerun me then).
3. Ask which missing VAR to fill (question tool, `multiple: true`); take a token-page URL as free text for `--url`, never the token itself.
4. Run `python3 .agents/skills/ct-auth/scripts/mcp_env_set.py <VAR> --launch` per VAR (5-minute timeout, wait for close). TTY → inline masked prompt; desktop → one window; headless → manual command (exit 2, hand to user). Never hand-roll terminals.
5. Shell use is live at once (`ct_project_env`); `{env:}` in configs needs an opencode restart before MCP retries.

Judge by exit code + the script's result line only. Tokens never pass through this session.
