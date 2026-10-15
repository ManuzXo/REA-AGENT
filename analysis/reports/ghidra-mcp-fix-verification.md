# Avvio MCP e provider Ghidra verificati

- Data: 2026-10-15.
- Host verificato: Windows x64, Node.js 22.19.0, REA 6.5.0, Ghidra 12.1.4, JDK 21.0.12.1.
- Domanda: il setup puo preparare un server MCP funzionante senza dipendere dalla cache npm globale?

## Risultato

Il bootstrap installa REA con `npm ci` e il lockfile versionato in `config/rea-runtime/`. Prima di pubblicare il runtime locale verifica versione, initialize, tools/list e tools/call binary_session. Lo snapshot e la registrazione Codex avviano direttamente Node e l'entry point locale, senza npm durante l'avvio MCP.

L'installazione reale da copia senza runtime, profili o cache e passata. Il percorso conteneva spazi. L'handshake ha restituito 207 strumenti e binary_session ha risposto. La cache npm globale con ws/wrapper.mjs vuoto non e stata modificata.

La registrazione utente `rea-ghidra` e stata aggiornata e riletta con `codex mcp get rea-ghidra --json`. Il comando registrato corrisponde allo snapshot `.rea/mcp/ghidra.json`. Un ulteriore test dello snapshot ha superato initialize, tools/list e binary_session.

## Evidenze

| Verifica | Comando ripetibile | Esito osservato |
| --- | --- | --- |
| Windows PowerShell 5.1 | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-setup.ps1` | Tutte le suite passano |
| PowerShell 7 | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-setup.ps1 -PowerShell pwsh.exe` | Tutte le suite passano |
| Copia pulita | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-clean-clone.ps1` | Installazione reale e MCP passano |
| Snapshot registrato | `node scripts/test-mcp.mjs --snapshot .rea/mcp/ghidra.json` | 207 strumenti e binary_session |
| Provider | `setup.bat -Action Doctor -Profile ghidra` | Doctor del runtime locale fuori sandbox restituisce healthy=true |
| Decompilazione | `node scripts/test-ghidra.mjs .rea/mcp/ghidra.json` | open_binary, list_procedures, batch_decompile e close_binary passano |
| Catalogo e link | `node scripts/check-documentation.mjs --package .tools/rea-runtime/6.5.0/node_modules/rea-agents` | 207 strumenti e 7 documenti, zero errori |

Log locali ignorati da Git:

- `.tools/verify-mcp-fix-ps51.log`.
- `.tools/verify-mcp-fix-ps7.log`.
- `.tools/verify-clean-clone.log`.
- `.tools/registered-ghidra-mcp-evidence.json`.
- `.tools/ghidra-doctor-unsandboxed.json`.
- `.tools/ghidra-smoke/2026-10-15T12-30-05-782Z/evidence.json` e `summary.json`.

## Prova del provider

Il test genera un PE x64 di 1024 byte con una funzione composta da `mov eax,42; ret`, senza import o accessi esterni. Il campione non viene eseguito. Ghidra lo importa e decompila staticamente tramite MCP con provider_id=ghidra.

- SHA-256 del campione: `30d35b06ab387cbfed984857742edcd800ff14893b4a088d8344c46111daebfb`.
- Indirizzo analizzato: `0x140001000`.
- Il test asserisce nel risultato decompilato `return 42;` oppure l'equivalente `return 0x2a;`.
- Esito osservato: `PASS: Ghidra decompila 0x140001000 e restituisce 42.`

## Errori coperti

Il bootstrap non pubblica installazioni parziali o che falliscono l'handshake. Le copie locali danneggiate sono conservate prima della sostituzione verificata. Il test del trasporto argomenti usa un processo Node reale e copre spazi, virgolette e metacaratteri su PowerShell 5.1.

La revisione ha trovato che il setup Ghidra salvava il profilo prima di doctor. Il test aggiunto falliva con `FAIL: doctor fallito conserva il profilo precedente`. Dopo aver spostato il salvataggio dopo doctor, lo stesso test passa su PowerShell 5.1 e 7. Le evidenze sono `.tools/profile-preservation-red.log`, `.tools/profile-preservation-green.log` e `.tools/profile-preservation-green-ps7.log`.

## Limiti

La sessione agente gia aperta ha mantenuto un errore di handshake anche dopo l'aggiornamento della registrazione. La connessione dell'agente corrente non viene dichiarata verificata. Il processo avviato dallo snapshot corretto funziona; occorre riconnettere il server o riavviare Codex per ricaricarlo.

Nella sandbox il controllo nativo Windows puo fallire con accesso negato. Fuori sandbox gli stessi controlli Ghidra sono passati. Il setup non disabilita questi controlli.

Il workflow Windows aggiunto verifica installer, bootstrap e MCP da checkout pulito. Non e stato ancora eseguito su GitHub e non scarica Ghidra per provare la decompilazione sul runner. La prova nativa descritta sopra e stata eseguita localmente.

La pubblicazione su GitHub e stata bloccata dalla revisione automatica, che richiede autorizzazione esplicita all'invio dei contenuti a ManuzXo/REA-AGENT. La correzione e salvata soltanto sul ramo locale `codex/fix-ghidra-mcp-runtime`. Chi scarica il repository remoto non riceve queste modifiche fino alla pubblicazione e integrazione.

## Attenzione dalla revisione indipendente

Revisore eseguito sul modello ereditato della sessione. Le famiglie alternative indicate dalla skill non erano disponibili.

Il difetto del salvataggio anticipato e stato corretto e verificato con test prima fallito e poi passato. Nessun altro difetto materiale segnalato e nessun commento da eliminare. Resta il limite della CI, che verifica MCP ma non la decompilazione Ghidra su runner GitHub.

## Decisioni

Il confronto tra cache locale npx offline e runtime Node diretto ha favorito il secondo perche evita la selezione della directory _npx e i download durante initialize. Il descrittore di lancio condiviso contiene Executable e Prefix ed e usato da CLI, esportazione e registrazione.

Principi applicati: Fix Root Causes per il difetto della cache; Model the Domain per il comando condiviso; Build the Lever e Prove It Works per i test ripetibili di copia pulita e decompilazione.
