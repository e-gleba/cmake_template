#Requires -Version 5.1
<#
.SYNOPSIS
    Windows PE import gate (Steam static-CRT check) using dumpbin.
.DESCRIPTION
    Lists every DLL each PE binary imports and fails when an import is on
    the forbidden list. Steam depots must not rely on the VC++
    redistributable being installed — link the C/C++ runtime statically
    (/MT) instead. Requires dumpbin in PATH (Visual Studio Developer
    Prompt; in CI use ilammy/msvc-dev-cmd).
.EXAMPLE
    ./check_pe_imports.ps1 -Path build/windows_msvc_steam_x86_64
.EXAMPLE
    ./check_pe_imports.ps1 -Path build/win -Forbidden vcruntime140.dll, msvcp140.dll
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,

    # Default denylist: the VC++ redistributable runtime.
    [Parameter()]
    [string[]]$Forbidden = @(
        'vcruntime140.dll', 'vcruntime140_1.dll',
        'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll',
        'concrt140.dll', 'vccorlib140.dll'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command dumpbin.exe -ErrorAction SilentlyContinue)) {
    Write-Host '::error::dumpbin.exe not found — run from a Visual Studio Developer Prompt (CI: ilammy/msvc-dev-cmd)'
    exit 2
}

$peFiles = New-Object System.Collections.Generic.List[string]
foreach ($p in $Path) {
    if (Test-Path -LiteralPath $p -PathType Container) {
        Get-ChildItem -LiteralPath $p -Recurse -File -Include '*.exe', '*.dll' |
            ForEach-Object { $peFiles.Add($_.FullName) }
    }
    elseif (Test-Path -LiteralPath $p -PathType Leaf) {
        $peFiles.Add((Get-Item -LiteralPath $p).FullName)
    }
    else {
        Write-Host "::error::no such file or directory: $p"
        exit 2
    }
}

if ($peFiles.Count -eq 0) {
    Write-Host "::error::no PE binaries found under: $($Path -join ', ')"
    exit 1
}

$failures = 0
foreach ($pe in $peFiles) {
    Write-Host "-- $pe"
    # A failed inspection must fail the gate — parsing dead output as an
    # empty import list would misreport the binary as fully static.
    $dump = dumpbin.exe /nologo /dependents $pe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "::error file=${pe}::dumpbin failed (exit $LASTEXITCODE)"
        $failures++
        continue
    }
    $imports = @($dump |
        Where-Object { $_ -match '^\s+(\S+\.dll)\s*$' } |
        ForEach-Object { $Matches[1] } |
        Sort-Object -Unique)
    if ($imports.Count -eq 0) {
        Write-Host '   no DLL imports — fully static, OK'
        continue
    }
    $imports | ForEach-Object { Write-Host "   $_" }
    foreach ($dll in $imports) {
        if ($Forbidden -contains $dll) {
            # -contains is case-insensitive
            Write-Host "::error file=${pe}::forbidden import '$dll' — link the C/C++ runtime statically (/MT) for Steam"
            $failures++
        }
    }
}

Write-Host '----------------------------------------------------------------------------'
if ($failures -gt 0) {
    Write-Host "::error::PE import gate FAILED — $failures violation(s)"
    exit 1
}
Write-Host "PE import gate passed — $($peFiles.Count) binaries clean"
