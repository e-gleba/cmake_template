// ct_dotenv_auth — automatic MCP token setup from a global .env file.
//
// Own implementation, zero dependencies (node:fs/os/path only). Only
// opencode needs to be installed: no Python, no npm packages, no shell
// wrapper, no rc-file edits. Official hooks only, see:
// https://opencode.ai/docs/plugins/#inject-environment-variables
// https://opencode.ai/docs/config/#env-vars
//
// Flow:
// 1. Plugin init reads the global ~/.config/opencode/.env (auto-created as
//    a 0600 template when absent) into process.env, so {env:VAR} in
//    .opencode/opencode.jsonc (MCP headers) resolves before MCP servers
//    spawn. Real environment values always win over the file.
// 2. `config` rewrites any {env:VAR} literal left in the merged config.
// 3. `shell.env` injects the file values into the bash tool + terminals.
// 4. `event` on session.created fails hard while a required token is
//    missing and tells exactly which file to fill, where each token page
//    is, and which setup script prompts for the values with masked input.
//    {env:} resolves at startup, so a restart is required after edits.
// 5. Tool ct_mcp_auth reports the status table, so the agent itself suggests
//    the fix on MCP 401s. No user-invoked setup command needed.

import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join } from "node:path"

type token_info = {
  server: string
  env_var: string
  token_page: string
  create: string
  required: boolean
}

// Server knowledge for this template. `required` entries are enforced;
// the intranet rows are commented examples — point them at your instances
// and flip required to true once the matching server lands in opencode.jsonc.
const KNOWN_TOKENS: token_info[] = [
  {
    server: "ct_github",
    env_var: "GITHUB_PERSONAL_ACCESS_TOKEN",
    token_page: "https://github.com/settings/tokens",
    create: "classic PAT with read scopes, see install guide link in .opencode/opencode.jsonc",
    required: true,
  },
  {
    server: "ct_teamcity (example)",
    env_var: "CT_TEAMCITY_TOKEN",
    token_page: "https://teamcity.internal/profile.html",
    create: "TeamCity access token for your user",
    required: false,
  },
  {
    server: "ct_sentry (example)",
    env_var: "CT_SENTRY_TOKEN",
    token_page: "https://sentry.internal/settings/auth-tokens/",
    create: "Sentry auth token (org access)",
    required: false,
  },
]

const ENV_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/
const ENV_PLACEHOLDER = /\{env:([A-Za-z_][A-Za-z0-9_]*)\}/g

export function global_env_path(): string {
  const explicit = (process.env.OPENCODE_DOTENV_PATH ?? "").trim()
  if (explicit !== "") return explicit
  const xdg = (process.env.XDG_CONFIG_HOME ?? "").trim()
  if (xdg !== "") return join(xdg, "opencode", ".env")
  return join(homedir(), ".config", "opencode", ".env")
}

export function parse_dotenv(text: string): Record<string, string> {
  const vars: Record<string, string> = {}
  for (const raw_line of text.split("\n")) {
    const line = raw_line.trim()
    if (line === "" || line.startsWith("#")) continue
    const body = line.startsWith("export ") ? line.slice(7).trim() : line
    const eq = body.indexOf("=")
    if (eq <= 0) continue
    const key = body.slice(0, eq).trim()
    if (!ENV_NAME.test(key)) continue
    vars[key] = unquote(body.slice(eq + 1).trim())
  }
  return vars
}

function unquote(value: string): string {
  if (value.startsWith('"')) {
    let out = ""
    let i = 1
    while (i < value.length) {
      const ch = value[i]
      if (ch === '"') break
      if (ch === "\\" && i + 1 < value.length) {
        const next = value[i + 1]
        if (next === "n") out += "\n"
        else if (next === "t") out += "\t"
        else if (next === "r") out += "\r"
        else out += next
        i += 2
        continue
      }
      out += ch
      i += 1
    }
    return out
  }
  if (value.startsWith("'")) {
    const end = value.indexOf("'", 1)
    return value.slice(1, end === -1 ? value.length : end)
  }
  const hash = value.indexOf("#")
  return (hash === -1 ? value : value.slice(0, hash)).trim()
}

// Quote a value for dotenv iff it needs it (bare tokens stay readable).
export function dotenv_quote(value: string): string {
  if (/^[A-Za-z0-9_@.:\/+=-]+$/.test(value)) return value
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`
}

// Upsert vars into file text: replace existing `VAR=`/`export VAR=` lines,
// append the rest with a comment. Comments and unknown lines stay
// byte-identical. Returns the new text (LF-joined, as given).
export function upsert_env_text(current: string, vars: Record<string, string>): string {
  const pending = new Map(Object.entries(vars))
  const lines = current === "" ? [] : current.split("\n")
  const out: string[] = []
  for (const line of lines) {
    const match = /^(export\s+)?([A-Za-z_][A-Za-z0-9_]*)=/.exec(line)
    if (match !== null && pending.has(match[2])) {
      out.push(`${match[2]}=${dotenv_quote(pending.get(match[2]) ?? "")}`)
      pending.delete(match[2])
      continue
    }
    out.push(line)
  }
  for (const [key, value] of pending) {
    out.push(`# ${key} — added by ct_auth_setup`)
    out.push(`${key}=${dotenv_quote(value)}`)
  }
  return out.join("\n")
}

// Read-modify-write the env file (creates it 0600 when absent).
export function upsert_env_file(path: string, vars: Record<string, string>): void {
  mkdirSync(dirname(path), { recursive: true })
  const current = existsSync(path) ? readFileSync(path, "utf8") : ""
  let next = upsert_env_text(current, vars)
  if (!next.endsWith("\n")) next += "\n"
  writeFileSync(path, next, { mode: 0o600 })
  try {
    chmodSync(path, 0o600)
  } catch {
    // Filesystem ignores chmod (e.g. FAT): content still written.
  }
}

export function config_candidates(directory: string, worktree: string): string[] {  const roots = [...new Set([worktree, directory].filter((root) => root !== ""))]
  const names = [
    join(".opencode", "opencode.jsonc"),
    join(".opencode", "opencode.json"),
    "opencode.json",
    "opencode.jsonc",
  ]
  return roots.flatMap((root) => names.map((name) => join(root, name)))
}

export function discover_env_vars(files: string[]): string[] {
  const found: string[] = []
  for (const file of files) {
    if (!existsSync(file)) continue
    let text = ""
    try {
      text = readFileSync(file, "utf8")
    } catch {
      continue
    }
    for (const match of text.matchAll(/\{env:([A-Za-z_][A-Za-z0-9_]*)\}/g)) {
      if (!found.includes(match[1])) found.push(match[1])
    }
  }
  return found
}

// Required set = {env:} vars wired in project config + always-required
// known entries (covers layouts the scan cannot see).
export function required_tokens(directory: string, worktree: string): token_info[] {
  const wanted = discover_env_vars(config_candidates(directory, worktree))
  const tokens: token_info[] = []
  for (const env_var of wanted) {
    const known = KNOWN_TOKENS.find((entry) => entry.env_var === env_var)
    tokens.push(
      known ?? {
        server: "see .opencode/opencode.jsonc",
        env_var,
        token_page: "see that server's docs for the token page",
        create: "paste the token below",
        required: true,
      },
    )
  }
  for (const entry of KNOWN_TOKENS) {
    if (entry.required && !tokens.some((token) => token.env_var === entry.env_var)) {
      tokens.push(entry)
    }
  }
  return tokens
}

function token_block(entry: token_info): string {
  return (
    `\n# ${entry.server} — token page: ${entry.token_page}\n` +
    `# ${entry.create}\n` +
    `${entry.env_var}=\n`
  )
}

export function render_template(tokens: token_info[]): string {
  let text =
    "# ct_dotenv_auth — global MCP tokens for opencode. Never commit this file.\n" +
    "# After editing, restart opencode: {env:} placeholders resolve at startup only.\n"
  for (const entry of tokens) text += token_block(entry)
  text +=
    "\n# Intranet examples — point at your instances, uncomment, flip required\n" +
    "# in KNOWN_TOKENS once the matching server lands in opencode.jsonc.\n" +
    "# CT_TEAMCITY_TOKEN=\n" +
    "# CT_SENTRY_TOKEN=\n"
  return text
}

// Creates the file (mode 600) or appends blocks for newly required vars.
// Never overwrites existing values.
export function ensure_env_file(path: string, tokens: token_info[]): "created" | "appended" | "ok" {
  mkdirSync(dirname(path), { recursive: true })
  if (!existsSync(path)) {
    mkdirSync(dirname(path), { recursive: true })
    writeFileSync(path, render_template(tokens), { mode: 0o600 })
    try {
      chmodSync(path, 0o600)
    } catch {
      // Filesystem ignores chmod (e.g. FAT): content still written.
    }
    return "created"
  }
  const present = parse_dotenv(readFileSync(path, "utf8"))
  const absent = tokens.filter((entry) => !(entry.env_var in present))
  if (absent.length === 0) return "ok"
  const current = readFileSync(path, "utf8")
  const prefix = current.endsWith("\n") ? current : current + "\n"
  writeFileSync(path, prefix + absent.map((entry) => token_block(entry)).join(""))
  return "appended"
}

// File values fill gaps only: real environment (and empty template lines)
// are left untouched. Returns the applied subset.
export function load_into_process(file_vars: Record<string, string>): Record<string, string> {
  const applied: Record<string, string> = {}
  for (const [key, value] of Object.entries(file_vars)) {
    if (value === "") continue
    if (process.env[key] === undefined || process.env[key] === "") {
      process.env[key] = value
      applied[key] = value
    }
  }
  return applied
}

export function missing_vars(tokens: token_info[]): token_info[] {
  return tokens.filter((entry) => (process.env[entry.env_var] ?? "").trim() === "")
}

export function format_error(miss: token_info[], env_path: string, setup_hint = ""): string {
  const lines = miss.map(
    (entry) => `  ${entry.env_var} (${entry.server}): ${entry.token_page} — ${entry.create}`,
  )
  const hint =
    setup_hint === "" ? "" : `\nMasked prompts, no AI needed: ${setup_hint} (or edit the file directly).`
  return (
    `[ct-dotenv-auth] missing MCP tokens: ${miss.map((entry) => entry.env_var).join(", ")}. ` +
    `Fill them in ${env_path}, then restart opencode ({env:} resolves at startup only).\n` +
    lines.join("\n") +
    hint
  )
}

export function status_report(tokens: token_info[], env_path: string, setup_hint = ""): string {
  const rows = tokens.map((entry) => {
    const state = (process.env[entry.env_var] ?? "").trim() === "" ? "missing" : "set"
    return `| ${entry.server} | ${entry.env_var} | ${state} | ${entry.token_page} |`
  })
  const hint =
    setup_hint === "" ? "" : `\nHuman path (no AI needed): ${setup_hint}.\n`
  return (
    `MCP tokens live in ${env_path} (global, never committed). ` +
    `After editing, restart opencode.\n` +
    hint +
    `\n| server | env var | status | token page |\n` +
    `|---|---|---|---|\n` +
    rows.join("\n")
  )
}

// Rewrites {env:VAR} survivors in the merged config. Unknown or empty vars
// stay literal, so a typo never silently blanks a value. Returns the count.
export function substitute_config(node: unknown): number {
  let replaced = 0
  const walk = (value: unknown): unknown => {
    if (typeof value === "string") {
      return value.replace(ENV_PLACEHOLDER, (literal, name: string) => {
        const resolved = process.env[name]
        if (resolved === undefined || resolved === "") return literal
        replaced += 1
        return resolved
      })
    }
    if (Array.isArray(value)) {
      for (let i = 0; i < value.length; i++) value[i] = walk(value[i])
      return value
    }
    if (value !== null && typeof value === "object") {
      for (const [key, nested] of Object.entries(value)) {
        ;(value as Record<string, unknown>)[key] = walk(nested)
      }
      return value
    }
    return value
  }
  walk(node)
  return replaced
}

async function log(client: unknown, level: string, message: string): Promise<void> {
  try {
    const app = (client as { app: { log: (arg: unknown) => Promise<unknown> } }).app
    await app.log({ body: { service: "ct_dotenv_auth", level, message } })
  } catch {
    // Headless runs without the log sink: stay silent, hooks still apply.
  }
}

export const CtDotenvAuth: Plugin = async (input) => {
  const env_path = global_env_path()
  const tokens = required_tokens(input.directory, input.worktree)
  const repo_root = input.worktree !== "" ? input.worktree : input.directory
  const setup_hint =
    `${repo_root}/.agents/scripts/auth/ct_auth_setup.sh (POSIX) or ` +
    `ct_auth_setup.ps1 (Windows)`
  let state: "created" | "appended" | "ok" | "unavailable" = "ok"
  let file_vars: Record<string, string> = {}
  try {
    state = ensure_env_file(env_path, tokens)
    file_vars = parse_dotenv(readFileSync(env_path, "utf8"))
  } catch {
    state = "unavailable"
  }
  const loaded = load_into_process(file_vars)
  await log(
    input.client,
    "info",
    `ct_dotenv_auth: ${env_path} ${state}, applied ${Object.keys(loaded).length} var(s)`,
  )

  return {
    config: async (cfg) => {
      const replaced = substitute_config(cfg)
      if (replaced > 0) {
        await log(input.client, "debug", `ct_dotenv_auth: substituted ${replaced} placeholder(s)`)
      }
    },
    "shell.env": async (_in, out) => {
      for (const key of Object.keys(file_vars)) {
        const value = process.env[key]
        if (value === undefined || value === "") continue
        if (out.env[key] !== undefined) continue
        out.env[key] = value
      }
    },
    event: async ({ event }) => {
      if (event.type !== "session.created") return
      const miss = missing_vars(tokens)
      if (miss.length === 0) return
      throw new Error(format_error(miss, env_path, setup_hint))
    },
    tool: {
      ct_mcp_auth: tool({
        description:
          "Report MCP token setup status (server, env var, set/missing, token page). " +
          "Call it when an MCP tool fails with 401/unauthorized or the user asks how " +
          "to configure MCP tokens. It never reads or prints token values.",
        args: {},
        execute: async () =>
          status_report(required_tokens(input.directory, input.worktree), env_path, setup_hint),
      }),
    },
  }
}

export default CtDotenvAuth
