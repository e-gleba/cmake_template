import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// Single source of truth: ~/.config/opencode/ct_project.env (override: CT_PROJECT_ENV_PATH).
// shell.env / create.before fires before every shell use, so reading here
// == live reload with no restart, no timer, no fs.watch to leak.
const file =
  process.env.CT_PROJECT_ENV_PATH ??
  path.join(
    process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), ".config"),
    "opencode",
    "ct_project.env",
  );

// Mutable state (mtime + cache) lives only inside this closure: module scope
// holds constants, nothing mutable is visible or reachable from outside.
function create_sync() {
  let mtime = -1;
  let cache = {};
  const load = () => {
    try {
      const st = fs.statSync(file); // 1 cheap syscall; re-parse only on change
      if (st.mtimeMs !== mtime) {
        mtime = st.mtimeMs;
        cache = parse(fs.readFileSync(file, "utf8"));
      }
    } catch {
      // Missing/unreadable: keep last good (or empty), never throw in a hook.
    }
    return cache;
  };
  // One injector for both APIs: V1 output and V2 event both carry .env.
  // Never throws and returns nothing: a hook failure would fail the
  // intercepted shell operation, so a missing .env is simply a no-op.
  return (target) => {
    if (target && target.env) Object.assign(target.env, load());
  };
}

const utf8_bom = "\uFEFF";
const double_quote = "\"";
const single_quote = "'";
const line_re = /^[^\S\n]*(?:export[^\S\n]+)?([A-Za-z_][A-Za-z0-9_]*)[^\S\n]*=[^\S\n]*(.*?)[^\S\n]*$/gm;

const unquote = (v) =>
  v.length > 1 &&
  (v[0] === double_quote || v[0] === single_quote) &&
  v[0] === v.at(-1)
    ? v.slice(1, -1)
    : v;

const parse = (text) => {
  const clean = text.startsWith(utf8_bom) ? text.slice(utf8_bom.length) : text;
  return Object.fromEntries(
    [...clean.matchAll(line_re)].map(([, key, raw]) => [key, unquote(raw)]),
  );
};

const sync = create_sync();
const shell_hook = async (_input, output) => sync(output);
const v1_hooks = { "shell.env": shell_hook };

// V1 classic (<1.18.29): named function export returning hooks.
export const CtProjectEnv = async () => v1_hooks;

// V1 object (1.18.29+) + V2 in one default export: V1 calls server(), V2 calls setup().
export default {
  id: "ct_project_env",
  async setup(ctx) {
    try {
      await ctx?.shell?.hook?.("create.before", sync);
    } catch {
      // Hosts without shell hooks: env injection stays V1-only, never fail load.
    }
  },
  async server() {
    return v1_hooks;
  },
};
