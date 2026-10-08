#!/bin/bash
# Fill MCP tokens via masked prompts and persist them to the global
# ~/.config/opencode/.env (mode 600). No Python, no npm, no AI model:
# plain bash + grep + awk writing beside opencode's own global config, so
# `git clean -fdx` in the repo can never touch the secrets.
# Usage: ct_auth_setup.sh                     (prompts for every value)
#        printf 'tok1\n\n' | ct_auth_setup.sh  (piped input works too;
#                                               empty line keeps current)
#
# Required vars come from {env:} in the project opencode.jsonc plus
# GITHUB_PERSONAL_ACCESS_TOKEN (always required). Token pages mirror the
# KNOWN_TOKENS table in .opencode/plugins/ct_dotenv_auth.ts; the template
# mirrors its render_template(). Same license as this repo (MIT, see
# license.md).
set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

env_path() {
    if [ -n "${OPENCODE_DOTENV_PATH:-}" ]; then
        printf '%s' "$OPENCODE_DOTENV_PATH"
    elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
        printf '%s/opencode/.env' "$XDG_CONFIG_HOME"
    else
        printf '%s/.config/opencode/.env' "$HOME"
    fi
}

token_page() {
    case "$1" in
        GITHUB_PERSONAL_ACCESS_TOKEN) printf 'https://github.com/settings/tokens' ;;
        *) printf "see that server's docs for the token page" ;;
    esac
}

# Quote a value for dotenv iff it needs it (matches the plugin parser).
dotenv_quote() {
    local v="$1"
    if [[ "$v" =~ ^[A-Za-z0-9_@.:\/+=-]+$ ]]; then
        printf '%s' "$v"
    else
        v="${v//\\/\\\\}"
        v="${v//\"/\\\"}"
        printf '"%s"' "$v"
    fi
}

# Presence check only: 0 when the var has a non-empty value, 1 otherwise.
is_set() {
    [ -f "$target" ] || return 1
    local tail
    tail="$(grep -E "^(export )?$1=" "$target" 2>/dev/null | tail -n 1 | sed -e 's/^[^=]*=//' -e 's/^[[:space:]]*//' || true)"
    [ -n "$tail" ] && [ "$tail" != '""' ] && [ "$tail" != "''" ]
}

target="$(env_path)"
umask 077
mkdir -p "$(dirname "$target")"

if [ ! -f "$target" ]; then
    {
        printf '# ct_dotenv_auth — global MCP tokens for opencode. Never commit this file.\n'
        printf '# After editing, restart opencode: {env:} placeholders resolve at startup only.\n'
        printf '\n# ct_github — token page: https://github.com/settings/tokens\n'
        printf '# classic PAT with read scopes, see install guide link in .opencode/opencode.jsonc\n'
        printf 'GITHUB_PERSONAL_ACCESS_TOKEN=\n'
        printf '\n# Intranet examples — point at your instances, uncomment, flip required\n'
        printf '# in KNOWN_TOKENS once the matching server lands in opencode.jsonc.\n'
        printf '# CT_TEAMCITY_TOKEN=\n'
        printf '# CT_SENTRY_TOKEN=\n'
    } > "$target"
    chmod 600 "$target"
fi

wanted=""
for name in .opencode/opencode.jsonc .opencode/opencode.json opencode.json opencode.jsonc; do
    if [ -f "$root/$name" ]; then
        hits="$(grep -oE '\{env:[A-Za-z_][A-Za-z0-9_]*\}' "$root/$name" 2>/dev/null | sed -e 's/{env://' -e 's/}$//' || true)"
        wanted="$wanted $hits"
    fi
done
wanted="$wanted GITHUB_PERSONAL_ACCESS_TOKEN"
vars="$(printf '%s' "$wanted" | tr ' ' '\n' | awk 'NF && !seen[$0]++')"

echo "Target: $target (mode 600). Input is hidden, empty line keeps the current value."
count=0
keys=""
for v in $vars; do
    if is_set "$v"; then
        state="set"
    else
        state="missing"
    fi
    printf '%s [%s] (token page: %s): ' "$v" "$state" "$(token_page "$v")"
    val=""
    IFS= read -r val || [ -n "$val" ]
    echo
    if [ -z "$val" ]; then
        echo "  kept ($state)"
        continue
    fi
    export "CT_NEWKEY_$count=$v"
    export "CT_NEWVAL_$count=$(dotenv_quote "$val")"
    keys="$keys $v"
    count=$((count + 1))
    echo "  updated"
done
val=""

if [ "$count" -gt 0 ]; then
    tmp="$(mktemp)"
    export CT_NEWCOUNT="$count"
    awk '
        BEGIN { n = ENVIRON["CT_NEWCOUNT"] + 0
                for (j = 0; j < n; j++) want[ENVIRON["CT_NEWKEY_" j]] = ENVIRON["CT_NEWVAL_" j] }
        { hit = ""
          for (k in want) if ($0 ~ ("^(export )?" k "=")) { hit = k }
          if (hit != "") { print hit "=" want[hit]; done[hit] = 1; next }
          print }
        END { for (j = 0; j < n; j++) { k = ENVIRON["CT_NEWKEY_" j]
                if (!(k in done)) print "# " k " — added by ct_auth_setup.sh\n" k "=" ENVIRON["CT_NEWVAL_" j] } }
    ' "$target" > "$tmp"
    cat "$tmp" > "$target"
    rm -f "$tmp"
    chmod 600 "$target"
fi

still=""
for v in $vars; do
    is_set "$v" || still="$still $v"
done
if [ -n "$still" ]; then
    echo "Saved to $target. Still missing:$still — rerun to fill them, then restart opencode."
    exit 1
fi
echo "Saved to $target. All required tokens set — restart opencode."
