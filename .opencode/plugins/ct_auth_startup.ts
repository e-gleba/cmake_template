import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"

const VARS = ["GITHUB_PERSONAL_ACCESS_TOKEN", "CT_TEAMCITY_TOKEN", "CT_SENTRY_TOKEN"]

function missing(): string[] {
  return VARS.filter((v) => {
    try {
      execFileSync("python3", [".opencode/scripts/mcp_env_set.py", v, "--check"], {
        stdio: "ignore",
      })
      return false
    } catch {
      return true
    }
  })
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
