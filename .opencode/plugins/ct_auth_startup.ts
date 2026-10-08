import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"

const VARS = ["GITHUB_PERSONAL_ACCESS_TOKEN", "CT_TEAMCITY_TOKEN", "CT_SENTRY_TOKEN"]

function missing(): string[] {
  try {
    const out = execFileSync(
      "python3",
      [".opencode/scripts/mcp_env_set.py", "--check-all", ...VARS.flatMap((v) => ["--var", v])],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    )
    const set = new Set(
      out
        .split("\n")
        .map((l) => l.trim().split(/\s+/)[0])
        .filter(Boolean),
    )
    return VARS.filter((v) => !set.has(v))
  } catch {
    return VARS.filter((v) => !process.env[v])
  }
}

export const CtAuthStartup: Plugin = async ({ client }) => {
  const miss = missing()
  if (miss.length > 0) {
    const msg = `[ct-auth] missing tokens: ${miss.join(", ")}. Run /ct_auth_mcps to set them up.`
    await client.app.log({ body: { service: "ct-auth", level: "warn", message: msg } })
  }

  return {
    event: async ({ event }) => {
      if (event.type !== "session.created") return
      const miss = missing()
      if (miss.length > 0) {
        await client.app.log({
          body: {
            service: "ct-auth",
            level: "warn",
            message: `[ct-auth] missing tokens: ${miss.join(", ")}. Run /ct_auth_mcps to set them up.`,
          },
        })
      }
    },
  }
}

export default CtAuthStartup
