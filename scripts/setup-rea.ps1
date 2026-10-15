[CmdletBinding()]
param([string]$ReaVersion, [string]$Client = 'codex')

$ErrorActionPreference = 'Stop'
if (-not $ReaVersion) { $ReaVersion = (Get-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'config/rea.json') -Raw | ConvertFrom-Json).reaVersion }
if ($ReaVersion -notmatch '^\d+\.\d+\.\d+$' -or $Client -notmatch '^[a-z][a-z0-9_]*$') { throw 'Versione REA o client non valido.' }

Write-Host "Avvio del setup REA per $Client. REA mostrera un piano e chiedera conferma prima di modificare la configurazione utente."
Write-Host 'Requisito: Node.js supportato e npm disponibili nel PATH.'

& npx.cmd --yes "rea-agents@$ReaVersion" setup --client $Client
if ($LASTEXITCODE -ne 0) {
    throw "Il setup REA e terminato con codice $LASTEXITCODE."
}

Write-Host "Riavvia il client e verifica con: npx.cmd --yes rea-agents@$ReaVersion doctor --client $Client --json"
