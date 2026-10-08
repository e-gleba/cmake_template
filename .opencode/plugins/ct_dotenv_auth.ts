// ct_dotenv_auth — MCP tokens from a global ct_project.env file.
//
// Own implementation, zero dependencies (node:fs/os/path only). Only
// opencode needs to be installed: no Python, no npm packages, no AI model.
// Official hooks only, see:
// https://opencode.ai/docs/plugins/#inject-environment-variables
// https://opencode.ai/docs/config/#env-vars
//
// Flow:
// 1. Plugin init reads the global ~/.config/opencode/ct_project.env
//    (auto-created as a bare 0600 template when absent) into process.env,
//    so {env:VAR} in .opencode/opencode.jsonc (MCP headers) resolves before
//    MCP servers spawn. Real environment values always win over the file.
// 2. `config` rewrites any {env:VAR} literal left in the merged config and
//    warns on placeholders nothing provides (typo'd var names).
// 3. `shell.env` injects the file values into the bash tool + terminals, so
//    shells the agent opens see the same tokens.
// 4. `event` on session.created fails hard while a required token is
//    missing and tells exactly which file to fill, where each token page
//    is, and which no-AI setup to run (/ct_auth dialog or setup scripts).
//    {env:} resolves at startup, so a restart is required after edits.

import type { Plugin } from "@opencode-ai/plugin"
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join } from "node:path"

type token_info = {
  server: string
  env_var: string
  token_page: string
  create: string
}

// Server knowledge for this template. Discovered `{env:}` vars not listed
// here still get enforced, with a generic token page.
const KNOWN_TOKENS: token_info[] = [
  {
    server: "ct_github",
    env_var: "GITHUB_PERSONAL_ACCESS_TOKEN",
    token_page: "https://github.com/settings/tokens",
    create: "classic PAT with read scopes, see install guide link in .opencode/opencode.jsonc",
  },
]

const ENV_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/
const ENV_PLACEHOLDER = /\{env:([A-Za-z_][A-Za-z0-9_]*)\}/g
const ENV_FILE_NAME = "ct_project.env"

function config_env_dir(): string {
  const xdg = (process.env.XDG_CONFIG_HOME ?? "").trim()
  if (xdg !== "") return join(xdg, "opencode")
  return join(homedir(), ".config", "opencode")
}

export function global_env_path(): string {
  const explicit = (process.env.OPENCODE_DOTENV_PATH ?? "").trim()
  if (explicit !== "") return explicit
  return join(config_env_dir(), ENV_FILE_NAME)
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

export function config_candidates(directory: string, worktree: string): string[] {
  const roots = [...new Set([worktree, directory].filter((root) => root !== ""))]
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
    for (const match of strip_jsonc_comments(text).matchAll(ENV_PLACEHOLDER)) {
      if (!found.includes(match[1])) found.push(match[1])
    }
  }
  return found
}

// First existing project config, or "" when none is reachable.
export function find_project_config(directory: string, worktree: string): string {
  for (const file of config_candidates(directory, worktree)) {
    if (existsSync(file)) return file
  }
  return ""
}

export function token_for_var(env_var: string): token_info {
  return (
    KNOWN_TOKENS.find((entry) => entry.env_var === env_var) ?? {
      server: "see .opencode/opencode.jsonc",
      env_var,
      token_page: "see that server's docs for the token page",
      create: "paste the token below",
    }
  )
}

// Strip // and /* */ comments, respecting strings (so `https://` inside a
// value survives). JSONC-aware; plain JSON passes through untouched.
export function strip_jsonc_comments(text: string): string {
  let out = ""
  let i = 0
  let quote = ""
  while (i < text.length) {
    const ch = text[i]
    if (quote !== "") {
      out += ch
      if (ch === "\\" && i + 1 < text.length) {
        out += text[i + 1]
        i += 2
        continue
      }
      if (ch === quote) quote = ""
      i += 1
      continue
    }
    if (ch === '"' || ch === "'") {
      quote = ch
      out += ch
      i += 1
      continue
    }
    if (ch === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i += 1
      continue
    }
    if (ch === "/" && text[i + 1] === "*") {
      i += 2
      while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) i += 1
      i += 2
      continue
    }
    out += ch
    i += 1
  }
  return out
}

export type mcp_server_vars = {
  name: string
  vars: string[]
}

// Per-server {env:} vars from the `mcp` section (dynamic: servers are never
// hardcoded). String-aware brace matching, so `{env:}` inside values and
// braces inside strings cannot confuse it.
export function discover_mcp_servers(text: string): mcp_server_vars[] {
  const clean = strip_jsonc_comments(text)
  const head = /"mcp"\s*:\s*\{/.exec(clean)
  if (head === null) return []
  const servers: mcp_server_vars[] = []
  let pos = head.index + head[0].length
  let depth = 1
  let quote = ""
  let entry_start = -1
  let entry_name = ""
  while (pos < clean.length && depth > 0) {
    const ch = clean[pos]
    if (quote !== "") {
      if (ch === "\\") {
        pos += 2
        continue
      }
      if (ch === quote) quote = ""
      pos += 1
      continue
    }
    if (ch === '"' || ch === "'") {
      quote = ch
      pos += 1
      continue
    }
    if (ch === "{") {
      if (depth === 1) {
        const name = /"([^"]+)"\s*:\s*$/.exec(clean.slice(0, pos))
        if (name !== null) {
          entry_start = pos
          entry_name = name[1]
        }
      }
      depth += 1
      pos += 1
      continue
    }
    if (ch === "}") {
      depth -= 1
      if (depth === 1 && entry_start !== -1) {
        const vars: string[] = []
        for (const match of clean.slice(entry_start, pos).matchAll(ENV_PLACEHOLDER)) {
          if (!vars.includes(match[1])) vars.push(match[1])
        }
        servers.push({ name: entry_name, vars })
        entry_start = -1
        entry_name = ""
      }
      pos += 1
      continue
    }
    pos += 1
  }
  return servers
}

// Required set = {env:} vars wired in project config + always-required
// known entries (covers layouts the scan cannot see).
export function required_tokens(directory: string, worktree: string): token_info[] {
  const wanted = discover_env_vars(config_candidates(directory, worktree))
  const tokens: token_info[] = []
  for (const env_var of wanted) {
    tokens.push(token_for_var(env_var))
  }
  for (const entry of KNOWN_TOKENS) {
    if (!tokens.some((token) => token.env_var === entry.env_var)) {
      tokens.push(entry)
    }
  }
  return tokens
}

export function render_template(tokens: token_info[]): string {
  let text =
    "# ct_project.env — MCP tokens for opencode. Never commit this file.\n" +
    "# After editing, restart opencode: {env:} placeholders resolve at startup only.\n"
  for (const entry of tokens) text += `\n${entry.env_var}=\n`
  return text
}

// Creates the file (mode 600) or appends lines for newly required vars.
// Never overwrites existing values.
export function ensure_env_file(path: string, tokens: token_info[]): "created" | "appended" | "ok" {
  mkdirSync(dirname(path), { recursive: true })
  if (!existsSync(path)) {
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
  writeFileSync(path, prefix + absent.map((entry) => `${entry.env_var}=\n`).join(""))
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


// Rewrites {env:VAR} survivors in the merged config. Unknown or empty vars
// stay literal, so a typo never silently blanks a value. Returns what was
// replaced and what is still referencing an unset var.
export function substitute_config(node: unknown): { replaced: number; unresolved: string[] } {
  let replaced = 0
  const missing = new Set<string>()
  const walk = (value: unknown): unknown => {
    if (typeof value === "string") {
      return value.replace(ENV_PLACEHOLDER, (literal, name: string) => {
        const resolved = process.env[name]
        if (resolved === undefined || resolved === "") {
          missing.add(name)
          return literal
        }
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
  return { replaced, unresolved: [...missing] }
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
  const names = Object.keys(loaded).sort().join(", ")
  await log(
    input.client,
    "info",
    `ct_dotenv_auth: ${env_path} ${state}, applied ${Object.keys(loaded).length} var(s)` +
      (names === "" ? "" : ` (${names})`),
  )

  return {
    config: async (cfg) => {
      const { replaced, unresolved } = substitute_config(cfg)
      if (replaced > 0) {
        await log(input.client, "debug", `ct_dotenv_auth: substituted ${replaced} placeholder(s)`)
      }
      if (unresolved.length > 0) {
        await log(
          input.client,
          "warn",
          `ct_dotenv_auth: unresolved placeholders left in config: ${unresolved.sort().join(", ")} ` +
            `(check spelling in opencode.jsonc and values in ${env_path})`,
        )
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
  }
}

export default CtDotenvAuth
