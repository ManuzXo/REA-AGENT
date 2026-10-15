[CmdletBinding()]
param([string]$ReaVersion, [string]$Client = 'codex')

$ErrorActionPreference = 'Stop'
if (-not $ReaVersion) { $ReaVersion = (Get-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'config/rea.json') -Raw | ConvertFrom-Json).reaVersion }
if ($ReaVersion -notmatch '^\d+\.\d+\.\d+$' -or $Client -notmatch '^[a-z][a-z0-9_]*$') { throw 'Versione REA o client non valido.' }
. (Join-Path $PSScriptRoot 'rea-profiles.ps1')

if ($Client -eq 'codex') {
    if (-not (Test-Path -LiteralPath (Get-ProfilePath default))) {
        Save-ReaProfile default ([pscustomobject]@{ schemaVersion = 1; reaVersion = $ReaVersion; template = 'builtin'; description = $script:ReaConfig.templates.builtin.description; environment = [pscustomobject]@{} })
    }
    $selected = Read-ReaProfile default
    Write-Host 'Verra registrato rea-default in Codex utente. Una registrazione con lo stesso nome verra aggiornata.'
    if ((Read-Host 'Procedere? [s/N]') -notmatch '^(s|si|y|yes)$') { Write-Host 'Registrazione annullata.'; return }
    Install-ReaRuntime $selected.reaVersion | Out-Null
    Export-ReaMcp default $selected
    Register-ReaMcp default $selected
    return
}

Write-Host "Avvio del setup REA per $Client. REA mostrera un piano e chiedera conferma prima di modificare la configurazione utente."
Write-Host 'Requisito: Node.js supportato e npm disponibili nel PATH.'

Install-ReaRuntime $ReaVersion | Out-Null
Invoke-ReaCommand $ReaVersion @('setup', '--client', $Client)

Write-Host "Riavvia il client. Il setup upstream per $Client gestisce una registrazione separata dagli snapshot locali."
