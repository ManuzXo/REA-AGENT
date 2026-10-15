$ErrorActionPreference = 'Stop'

Write-Host 'Avvio del setup REA per Codex. REA mostrerà un piano e chiederà conferma prima di modificare la configurazione utente.'
Write-Host 'Requisito: Node.js supportato e npm disponibili nel PATH.'

& npx --yes rea-agents@latest setup --client codex
if ($LASTEXITCODE -ne 0) {
    throw "Il setup REA è terminato con codice $LASTEXITCODE."
}

Write-Host 'Setup completato. Riavvia Codex e verifica con: npx --yes rea-agents@latest doctor --client codex --json'
