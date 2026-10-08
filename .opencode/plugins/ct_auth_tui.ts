// ct_auth_tui — native /ct_auth TUI command for MCP token setup.
//
// TUI-side companion to ct_dotenv_auth.ts (server): lists the MCP servers
// wired in the project opencode.jsonc (dynamic `{env:}` discovery, never a
// hardcoded list), then opens one DialogPrompt per missing token and
// persists answers to the global ~/.config/opencode/ct_project.env
// (mode 600). The token page shows once, as the input hint — plain strings
// only, no JSX toolchain (raw string children crash the reconciler). No AI
// model involved — TUI commands run locally. Secrets never enter the repo.
//
// Target-exclusive TUI module per
// https://github.com/anomalyco/opencode/blob/v1.18.16/packages/opencode/specs/tui-plugins.md:
// default-export { id, tui } only, listed in .opencode/tui.json. Named
// exports are ignored by the TUI loader (and would be picked up by the
// server loader), so this file has none. No JSX: components are called as
// plain functions, so no @opentui runtime dependency is needed.

import type { TuiPlugin, TuiPluginApi, TuiPluginModule } from "@opencode-ai/plugin/tui"
import { readFileSync } from "node:fs"
import {
  discover_mcp_servers,
  ensure_env_file,
  find_project_config,
  global_env_path,
  parse_dotenv,
  required_tokens,
  token_for_var,
  upsert_env_file,
  type token_info,
} from "./ct_dotenv_auth.ts"

const PLUGIN_ID = "ct.auth"
const SELECT_ALL = "__all"

type auth_group = {
  name: string
  tokens: token_info[]
}

function file_set_vars(env_path: string): Set<string> {
  let text = ""
  try {
    text = readFileSync(env_path, "utf8")
  } catch {
    return new Set()
  }
  const set = new Set<string>()
  for (const [key, value] of Object.entries(parse_dotenv(text))) {
    if (value !== "") set.add(key)
  }
  return set
}

function repo_root_of(api: TuiPluginApi): string {
  const worktree = api.state.path.worktree
  if (worktree !== "") return worktree
  return api.state.path.directory
}

function is_url(text: string): boolean {
  return text.startsWith("https://")
}

// All user text travels through string props (title/placeholder/option
// descriptions) that the host renders inside proper <text> nodes. Never
// return raw strings from a render function: the reconciler crashes the
// whole TUI with an orphan-text error (seen 1.18.35, ct_auth_tui step()).
// No JSX here by design, so there is no other text slot.
function prompt_title(index: number, total: number, entry: token_info): string {
  return `[${index + 1}/${total}] ${entry.env_var} (${entry.server})`
}

function describe_missing(miss: token_info[]): string {
  return `missing: ${miss.map((entry) => entry.env_var).join(", ")}`
}

// Brief instruction + hint inside the input itself. Plain string prop.
function prompt_placeholder(entry: token_info): string {
  if (is_url(entry.token_page)) {
    return `Open ${entry.token_page} and paste the token here`
  }
  return entry.token_page
}

function missing_of(group: auth_group, present: Set<string>): token_info[] {
  return group.tokens.filter((entry) => !present.has(entry.env_var))
}

function count_missing(groups: auth_group[], env_path: string): number {
  const present = file_set_vars(env_path)
  return groups.reduce((n, group) => n + missing_of(group, present).length, 0)
}

// Groups follow the `mcp` section order; required vars that no server block
// covers (providers, odd layouts) land in a trailing group.
function auth_groups(root: string, tokens: token_info[]): auth_group[] {
  const groups: auth_group[] = []
  const covered = new Set<string>()
  const cfg = find_project_config(root, root)
  if (cfg !== "") {
    try {
      for (const server of discover_mcp_servers(readFileSync(cfg, "utf8"))) {
        if (server.vars.length === 0) continue
        for (const v of server.vars) covered.add(v)
        groups.push({ name: server.name, tokens: server.vars.map((v) => token_for_var(v)) })
      }
    } catch {
      // Unreadable config: fall through to the flat group below.
    }
  }
  const others = tokens.filter((entry) => !covered.has(entry.env_var))
  if (others.length > 0) {
    groups.push({ name: groups.length === 0 ? "required variables" : "other variables", tokens: others })
  }
  return groups
}

function prompt_chain(
  api: TuiPluginApi,
  env_path: string,
  groups: auth_group[],
  items: token_info[],
): void {
  const dialog = api.ui.dialog
  let saved = 0
  const step = (index: number): void => {
    if (index >= items.length) {
      const rest = count_missing(groups, env_path)
      if (rest === 0) {
        dialog.clear()
        api.ui.toast({
          variant: "success",
          title: "ct-auth",
          message: `Saved ${saved} token(s) to ${env_path} — restart opencode.`,
        })
        return
      }
      api.ui.toast({
        variant: "warning",
        title: "ct-auth",
        message: `Saved ${saved} token(s), ${rest} still missing.`,
      })
      open_list(api, env_path, groups)
      return
    }
    const entry = items[index]
    dialog.replace(() =>
      api.ui.DialogPrompt({
        title: prompt_title(index, items.length, entry),
        placeholder: prompt_placeholder(entry),
        onConfirm: (value: string) => {
          if (value.trim() !== "") {
            try {
              upsert_env_file(env_path, { [entry.env_var]: value.trim() })
              saved += 1
            } catch {
              api.ui.toast({
                variant: "error",
                title: "ct-auth",
                message: `Cannot write ${env_path}.`,
              })
              open_list(api, env_path, groups)
              return
            }
          }
          step(index + 1)
        },
        onCancel: () => open_list(api, env_path, groups),
      }),
    )
  }
  step(0)
}

function open_list(api: TuiPluginApi, env_path: string, groups: auth_group[]): void {
  const present = file_set_vars(env_path)
  const total = groups.reduce((n, group) => n + missing_of(group, present).length, 0)
  if (total === 0) {
    api.ui.toast({
      variant: "success",
      title: "ct-auth",
      message: `All MCP tokens set in ${env_path}. Restart opencode to apply.`,
    })
    return
  }
  // Actionable first, ready last (stable: config order kept on ties).
  const rows = groups
    .map((group) => ({ group, miss: missing_of(group, present) }))
    .sort((a, b) => b.miss.length - a.miss.length)
  const options = [
    {
      title: "All servers",
      value: SELECT_ALL,
      description: `${total} value(s) missing`,
    },
    ...rows.map((row) => {
      const ready = row.miss.length === 0
      const option: {
        title: string
        value: string
        description: string
        disabled?: boolean
      } = {
        title: row.group.name,
        value: row.group.name,
        description: ready ? "all set" : describe_missing(row.miss),
      }
      if (ready) option.disabled = true
      return option
    }),
  ]
  api.ui.dialog.replace(() =>
    api.ui.DialogSelect({
      title: `MCP authorizations — ${total} missing`,
      placeholder: "Pick a server — Esc when done",
      flat: true,
      options,
      onSelect: (option) => {
        const value = String(option.value)
        if (value === SELECT_ALL) {
          prompt_chain(
            api,
            env_path,
            groups,
            groups.flatMap((group) => missing_of(group, file_set_vars(env_path))),
          )
          return
        }
        const group = groups.find((entry) => entry.name === value)
        if (group === undefined) {
          open_list(api, env_path, groups)
          return
        }
        const miss = missing_of(group, file_set_vars(env_path))
        if (miss.length === 0) {
          api.ui.toast({ variant: "success", title: "ct-auth", message: `${group.name}: already set.` })
          open_list(api, env_path, groups)
          return
        }
        prompt_chain(api, env_path, groups, miss)
      },
    }),
  )
}

function open_setup(api: TuiPluginApi): void {
  const env_path = global_env_path()
  const root = repo_root_of(api)
  const tokens = required_tokens(root, root)
  try {
    ensure_env_file(env_path, tokens)
  } catch {
    api.ui.toast({
      variant: "error",
      title: "ct-auth",
      message: `Cannot write ${env_path}. Fill it in an editor instead.`,
    })
    return
  }
  open_list(api, env_path, auth_groups(root, tokens))
}

const CtAuthTui: TuiPlugin = async (api) => {
  api.keymap.registerLayer({
    commands: [
      {
        name: "ct.auth.setup",
        title: "MCP authorizations",
        category: "Plugin",
        namespace: "palette",
        slashName: "ct_auth",
        run: () => open_setup(api),
      },
    ],
    bindings: [],
  })
}

const plugin: TuiPluginModule = {
  id: PLUGIN_ID,
  tui: CtAuthTui,
}

export default plugin
