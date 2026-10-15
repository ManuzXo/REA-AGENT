# REA-AGENT

Repository personale per preparare sessioni di reverse engineering assistite da [REA](https://github.com/morluto/rea). Qui trovi workflow, istruzioni per l’agente e note di analisi; REA e gli strumenti di disassemblaggio restano installazioni locali.

## Requisiti

- Windows 10/11 x64 (workflow principale documentato per Windows).
- Node.js 22.19+, 24.11+ oppure 26+, con npm.
- Codex desktop o CLI.
- Per analisi native: Ghidra, installabile dal setup opzionale, oppure IDA già installato e configurato. REA non installa né concede licenze IDA.

REA analizza i file localmente. I risultati passati all’agente seguono anche le regole del provider del modello scelto.

## Avvio rapido

1. Clona questo repository e aprilo in Codex.
2. Avvia `setup.bat` dalla cartella del repository, anche con doppio clic:

   ```bat
   setup.bat
   ```

3. Scegli se configurare solo REA, scaricare Ghidra con il JDK, oppure collegare installazioni esistenti. Il download richiede conferma. Le installazioni portatili restano in `.tools/`, ignorata da Git, senza privilegi amministrativi. Per opzioni e recupero dagli errori, segui [la guida al setup](docs/setup-ghidra.md).
4. Leggi e approva il piano mostrato da REA. La procedura registra il server MCP nel profilo Codex dell'utente e installa le istruzioni REA corrispondenti. I file utente non vengono committati nel repository.
5. Riavvia Codex e controlla lo stato:

   ```powershell
   npx --yes rea-agents@6.5.0 doctor --client codex --json
   ```

6. Per iniziare un'analisi nativa, segui [docs/native-analysis.md](docs/native-analysis.md).

Il setup usa REA 6.5.0, Ghidra 12.1.4 e Temurin JDK 21.0.12.1+1. Le versioni e gli hash dei due archivi sono fissati nello script. Per aggiornare la combinazione, verifica prima la compatibilità nella [documentazione REA](https://github.com/morluto/rea/blob/main/docs/installation.md#ghidra), poi aggiorna script e documentazione insieme.

Per configurare soltanto REA da PowerShell resta disponibile `.\scripts\setup-rea.ps1`.

## Struttura

- `AGENTS.md`: istruzioni operative caricate dall’agente nel repository.
- `docs/native-analysis.md`: flusso per binari nativi con Ghidra e IDA.
- `docs/setup-ghidra.md`: installazione opzionale e collegamento Ghidra tramite REA MCP.
- `analysis/samples/`: campioni locali, ignorati da Git.
- `analysis/reports/`: rapporti e appunti versionabili; non salvare qui binari o segreti.
- `scripts/setup-rea.ps1`: avvio guidato del setup REA per Codex.
- `setup.bat` e `scripts/setup.ps1`: scelta e preparazione degli strumenti su Windows.
- `scripts/test-setup.ps1`: verifiche del setup con download e comandi esterni simulati.
- `.tools/`: installazioni locali, escluse da Git.

## Workflow di analisi

Chiedi all’agente una domanda circoscritta e richiedi evidenze verificabili: hash del campione, formato/architettura, simboli o indirizzi, pseudocodice/assembly rilevante, ipotesi e limiti. Consulta [docs/native-analysis.md](docs/native-analysis.md) per il flusso completo.

Usa REA soltanto su software che possiedi o che sei autorizzato ad analizzare. Prima di committare un rapporto, rimuovi dati riservati e verifica che il campione non sia stato incluso.
