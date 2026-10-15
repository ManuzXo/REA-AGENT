[CmdletBinding()]
param(
    [string]$Profile = 'default',
    [string]$Command = '--help',
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$ReaArguments
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'rea-profiles.ps1')
. (Join-Path $PSScriptRoot 'setup-ghidra.ps1')
try {
    if ($Command -eq 'mcp') { throw 'Per MCP usa lo snapshot diretto generato da setup.bat -Action Mcp. Il launcher PowerShell e riservato alla CLI.' }
    $selected = Read-ReaProfile $Profile
    $npx = Get-NpxCommand
    Invoke-InReaProfile $selected {
        & $npx --yes "rea-agents@$($selected.reaVersion)" $Command @ReaArguments
        if ($LASTEXITCODE -ne 0) { throw "REA terminato con codice $LASTEXITCODE." }
    }
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
