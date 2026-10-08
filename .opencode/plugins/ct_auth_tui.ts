// ct_auth_tui — native /ct_auth TUI command for MCP token setup.
//
// TUI-side companion to ct_dotenv_auth.ts (server): opens one DialogPrompt
// per missing token and persists answers to the same global
// ~/.config/opencode/.env (mode 600). No AI model involved — TUI commands
// run locally. Secrets never enter the repo.
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
  ensure_env_file,
  global_env_path,
  parse_dotenv,
  required_tokens,
  upsert_env_file,
  type token_info,
} from "./ct_dotenv_auth.ts"

const PLUGIN_ID = "ct.auth"

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
  const present = file_set_vars(env_path)
  const queue = tokens.filter((entry) => !present.has(entry.env_var))
  if (queue.length === 0) {
    api.ui.toast({
      variant: "success",
      title: "ct-auth",
      message: `All MCP tokens set in ${env_path}. Restart opencode to apply.`,
    })
    return
  }
  const dialog = api.ui.dialog
  let saved = 0
  const step = (index: number): void => {
    if (index >= queue.length) {
      dialog.clear()
      api.ui.toast({
        variant: "success",
        title: "ct-auth",
        message: `Saved ${saved} token(s) to ${env_path} — restart opencode.`,
      })
      return
    }
    const entry: token_info = queue[index]
    dialog.replace(() =>
      api.ui.DialogPrompt({
        title: `[${index + 1}/${queue.length}] ${entry.env_var} (${entry.server})`,
        placeholder: entry.token_page,
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
              dialog.clear()
              return
            }
          }
          step(index + 1)
        },
        onCancel: () => dialog.clear(),
      }),
    )
  }
  step(0)
}

const CtAuthTui: TuiPlugin = async (api) => {
  api.keymap.registerLayer({
    commands: [
      {
        name: "ct.auth.setup",
        title: "Fill MCP tokens",
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
