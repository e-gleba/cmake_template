# Fill MCP tokens via masked prompts and persist them to the global
# ~/.config/opencode/.env (user profile, UTF-8 without BOM). No Python, no
# npm, no AI model: plain PowerShell writing beside opencode's own global
# config, so `git clean -fdx` in the repo can never touch the secrets.
# Usage: ct_auth_setup.ps1   (prompts for every value; empty keeps current)
#
# Required vars come from {env:} in the project opencode.jsonc plus
# GITHUB_PERSONAL_ACCESS_TOKEN (always required). Token pages mirror the
# KNOWN_TOKENS table in .opencode/plugins/ct_dotenv_auth.ts; the template
# mirrors its render_template(). Same license as this repo (MIT, see
# license.md).
param()
$root = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

function Env-Path {
    if ($env:OPENCODE_DOTENV_PATH) { return $env:OPENCODE_DOTENV_PATH }
    if ($env:XDG_CONFIG_HOME) { return (Join-Path $env:XDG_CONFIG_HOME 'opencode/.env') }
    return (Join-Path $HOME '.config/opencode/.env')
}

function Token-Page([string]$v) {
    if ($v -eq 'GITHUB_PERSONAL_ACCESS_TOKEN') { return 'https://github.com/settings/tokens' }
    return "see that server's docs for the token page"
}

# Quote a value for dotenv iff it needs it (matches the plugin parser).
function Dotenv-Quote([string]$v) {
    if ($v -match '^[A-Za-z0-9_@.:\/+=-]+$') { return $v }
    return '"' + ($v.Replace('\', '\\').Replace('"', '\"')) + '"'
}

# Presence check only (never returns values): $true when non-empty.
function Is-Set([string[]]$lines, [string]$v) {
    $tail = $lines | Select-String -Pattern "^(?:export\s+)?$v\s*=\s*(.*)$" | Select-Object -Last 1
    if (-not $tail) { return $false }
    $t = $tail.Matches[0].Groups[1].Value.Trim()
    return ($t -ne '' -and $t -ne '""' -and $t -ne "''")
}

$target = Env-Path
$dir = Split-Path $target -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if (-not (Test-Path $target)) {
    $template = @(
        '# ct_dotenv_auth — global MCP tokens for opencode. Never commit this file.'
        '# After editing, restart opencode: {env:} placeholders resolve at startup only.'
        ''
        '# ct_github — token page: https://github.com/settings/tokens'
        '# classic PAT with read scopes, see install guide link in .opencode/opencode.jsonc'
        'GITHUB_PERSONAL_ACCESS_TOKEN='
        ''
        '# Intranet examples — point at your instances, uncomment, flip required'
        '# in KNOWN_TOKENS once the matching server lands in opencode.jsonc.'
        '# CT_TEAMCITY_TOKEN='
        '# CT_SENTRY_TOKEN='
    )
    [IO.File]::WriteAllText($target, ($template -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}

$wanted = @()
foreach ($n in @('.opencode/opencode.jsonc', '.opencode/opencode.json', 'opencode.json', 'opencode.jsonc')) {
    $f = Join-Path $root $n
    if (Test-Path $f) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f), '\{env:([A-Za-z_][A-Za-z0-9_]*)\}')) {
            if ($wanted -notcontains $m.Groups[1].Value) { $wanted += $m.Groups[1].Value }
        }
    }
}
if ($wanted -notcontains 'GITHUB_PERSONAL_ACCESS_TOKEN') { $wanted += 'GITHUB_PERSONAL_ACCESS_TOKEN' }

$lines = @([IO.File]::ReadAllText($target) -split "`n")
Write-Output "Target: $target. Input is hidden, empty line keeps the current value."
$updates = @{}
foreach ($v in $wanted) {
    $state = 'missing'
    if (Is-Set $lines $v) { $state = 'set' }
    $sec = Read-Host -Prompt "$v [$state] (token page: $(Token-Page $v))" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        $val = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        $sec.Dispose()
    }
    if ([string]::IsNullOrEmpty($val)) {
        Write-Output "  kept ($state)"
    } else {
        $updates[$v] = Dotenv-Quote $val
        Write-Output "  updated"
    }
}

if ($updates.Count -gt 0) {
    $done = @{}
    $out = foreach ($line in $lines) {
        $hit = ''
        foreach ($k in $updates.Keys) {
            if ($line -match "^(?:export\s+)?$k\s*=") { $hit = $k; break }
        }
        if ($hit -ne '') { $done[$hit] = $true; "$hit=$($updates[$hit])" } else { $line }
    }
    foreach ($k in $updates.Keys) {
        if (-not $done.ContainsKey($k)) { $out += "# $k — added by ct_auth_setup.ps1"; $out += "$k=$($updates[$k])" }
    }
    [IO.File]::WriteAllText($target, ($out -join "`n").TrimEnd("`n") + "`n", [Text.UTF8Encoding]::new($false))
}

$lines = @([IO.File]::ReadAllText($target) -split "`n")
$still = @($wanted | Where-Object { -not (Is-Set $lines $_) })
if ($still.Count -gt 0) {
    Write-Output "Saved to $target. Still missing: $($still -join ' ') — rerun to fill them, then restart opencode."
    exit 1
}
Write-Output "Saved to $target. All required tokens set — restart opencode."
