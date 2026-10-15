# Verifica del workspace REA

Verifica eseguita il 15 ottobre 2026 su Windows. Il riferimento eseguibile e il pacchetto npm `rea-agents@6.5.0` gia presente nella cache locale del repository.

## Risultati osservati

| Controllo | Risultato |
| --- | --- |
| Suite PowerShell 5.1 | 61 controlli PASS. |
| Suite PowerShell 7 | 61 controlli PASS, eseguiti direttamente con `pwsh.exe`. |
| Documentazione | 7 documenti controllati, 0 errori di collegamenti e nomenclatura. |
| Inventario | 207 nomi MCP confrontati con `TOOL_CONTRACTS` del pacchetto npm, nessuna differenza. |
| Server MCP reale | Avvio tramite `cmd.exe /d /c npx.cmd`, `initialize` e `tools/list` riusciti. Ricevuti 207 strumenti. |
| CLI reale | `--help` e `capabilities --json` riusciti dal pacchetto npm locale. |
| BAT reali | Menu generale e installer in modalita istruzioni avviati senza installazione. |
| Sintassi e diff | `node --check` sui due script JavaScript e `git diff --check` riusciti. |

I 29 BAT `install-*` comprendono Ghidra e 28 voci nel catalogo degli strumenti facoltativi. Alcuni installano software dopo conferma. Altri mostrano la procedura ufficiale e i limiti della piattaforma. La disponibilita di un BAT non significa che lo strumento sia utilizzabile su Windows.

## Come ripetere i controlli

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-setup.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-setup.ps1 -PowerShell pwsh.exe
node .\scripts\check-documentation.mjs --package 'PERCORSO\node_modules\rea-agents'
node .\scripts\test-mcp.mjs 'PERCORSO\cache-npm-esistente'
```

Il controllo MCP usa npm in modalita offline. La cache deve contenere la versione fissata in `config/rea.json`. Non scarica il pacchetto e non modifica le registrazioni dei client.

Nel sandbox AppContainer il TEMP predefinito impediva il rename delle directory anche prima delle modifiche. Le suite sono state eseguite con `TEMP` e `TMP` impostati su cartelle locali sotto `.tools/`. Questo limite dell'ambiente non e stato presentato come difetto degli installer.

## Difetti corretti durante la verifica

- Il nome locale `rea.bat` intercettava il comando di npm. Il launcher ora si chiama `rea-profile.bat`. Il controllo documentazione vieta la reintroduzione della collisione.
- La registrazione nativa da PowerShell 5.1 perdeva virgolette JSON. Ora il processo riceve argomenti Windows codificati esplicitamente. I test verificano i valori osservati da Node, compresi spazi, backslash finali, virgolette, percentuali e metacaratteri.
- La documentazione attribuiva a Ghidra il modo `Instructions` degli altri installer. Ora descrive il suo script e i suoi modi separatamente.
- La diagnosi dei profili senza motore non deve cercare la registrazione standard `rea`. Usa `capabilities --json`. Le registrazioni `rea-<nome>` si controllano con la CLI del client e la sessione MCP riconnessa.

## Limiti della verifica

I download e i comandi di installazione sono simulati nelle suite. Non sono stati installati Ghidra, Java, JADX, Apktool o WABT, ne modificati i profili utente Codex. Nessun campione binario e stato aperto o eseguito. Le verifiche Linux, macOS, dei dispositivi Android, delle licenze e dei motori reali restano da eseguire sull'host scelto dall'utente.

Una revisione indipendente con il modello disponibile `gpt-6.1-sol` ha individuato il problema delle virgolette e l'inesattezza della guida Ghidra prima della correzione. Non ha rilevato commenti di codice da eliminare. Le famiglie di modelli richieste dalle skill per una revisione fra modelli diversi non sono disponibili in questa sessione.
