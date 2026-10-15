# REA-AGENT

Repository personale per preparare sessioni di reverse engineering assistite da [REA](https://github.com/morluto/rea). Qui trovi workflow, istruzioni per l’agente e note di analisi; REA e gli strumenti di disassemblaggio restano installazioni locali.

## Requisiti

- Windows 10/11 x64 (workflow principale documentato per Windows).
- Node.js 22.19+, 24.11+ oppure 26+, con npm.
- Codex desktop o CLI.
- Per analisi native: Ghidra o IDA già installato e configurato. REA non installa né concede licenze IDA.

REA analizza i file localmente. I risultati passati all’agente seguono anche le regole del provider del modello scelto.

## Avvio rapido

1. Clona questo repository e aprilo in Codex.
2. Avvia PowerShell nella cartella del repository ed esegui:

   ```powershell
   .\scripts\setup-rea.ps1
   ```

3. Leggi e approva il piano mostrato da REA. La procedura registra il server MCP nel profilo Codex dell’utente e installa le istruzioni REA corrispondenti; questi file utente non vengono committati nel repository.
4. Riavvia Codex e controlla lo stato:

   ```powershell
   npx --yes rea-agents@latest doctor --client codex --json
   ```

5. Per impostare un provider nativo, segui [docs/native-analysis.md](docs/native-analysis.md).

Per aggiornare la registrazione usa di nuovo `npx --yes rea-agents@latest setup --client codex`, rivedi il piano e riavvia Codex.

## Struttura

- `AGENTS.md`: istruzioni operative caricate dall’agente nel repository.
- `docs/native-analysis.md`: flusso per binari nativi con Ghidra e IDA.
- `analysis/samples/`: campioni locali, ignorati da Git.
- `analysis/reports/`: rapporti e appunti versionabili; non salvare qui binari o segreti.
- `scripts/setup-rea.ps1`: avvio guidato del setup REA per Codex.

## Workflow di analisi

Chiedi all’agente una domanda circoscritta e richiedi evidenze verificabili: hash del campione, formato/architettura, simboli o indirizzi, pseudocodice/assembly rilevante, ipotesi e limiti. Consulta [docs/native-analysis.md](docs/native-analysis.md) per il flusso completo.

Usa REA soltanto su software che possiedi o che sei autorizzato ad analizzare. Prima di committare un rapporto, rimuovi dati riservati e verifica che il campione non sia stato incluso.
