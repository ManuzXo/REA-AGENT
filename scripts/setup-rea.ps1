[CmdletBinding()]
param([string]$ReaVersion = '6.5.0')

$ErrorActionPreference = 'Stop'

Write-Host 'Avvio del setup REA per Codex. REA mostrera un piano e chiedera conferma prima di modificare la configurazione utente.'
Write-Host 'Requisito: Node.js supportato e npm disponibili nel PATH.'

& npx.cmd --yes "rea-agents@$ReaVersion" setup --client codex
if ($LASTEXITCODE -ne 0) {
    throw "Il setup REA e terminato con codice $LASTEXITCODE."
}

Write-Host "Riavvia Codex e verifica con: npx.cmd --yes rea-agents@$ReaVersion doctor --client codex --json"
