# Perche rea-ghidra chiude la connessione durante initialize?

Aggiornamento: la correzione e le verifiche successive sono in [ghidra-mcp-fix-verification.md](ghidra-mcp-fix-verification.md). Le raccomandazioni sotto descrivono lo stato iniziale della diagnosi.

- Data: 2026-10-15.
- Ambito: avvio MCP, senza aprire o eseguire campioni.
- Runtime osservato: Node.js 22.19.0, REA 6.5.0, Windows x64.
- Configurazione utente letta, non modificata.

## Risposta

La copia REA nella cache npm utente contiene una dipendenza incompleta. Il file `C:\Users\e.rispoli\AppData\Local\npm-cache\_npx\ad9a3fdbcad992c6\node_modules\ws\wrapper.mjs` e vuoto. Avviando direttamente il relativo entrypoint MCP, Node termina con codice 1 prima di rispondere a initialize.

La stessa versione REA nella cache locale `.tools/npm-cache` supera initialize e tools/list, restituendo 207 strumenti. Questo dimostra un percorso di avvio funzionante e circoscrive il difetto riprodotto alla copia della cache utente.

Il collegamento tra quella copia e il fallimento del processo avviato da Codex e una deduzione forte, non un percorso di caricamento estratto dal processo Codex. I log desktop disponibili riportano la chiusura dell'handshake, ma non lo stack JavaScript del server.

## Configurazione osservata

`C:\Users\e.rispoli\.codex\config.toml`, righe 113-120, registra:

```toml
[mcp_servers.rea-ghidra]
command = "cmd.exe"
args = ["/d", "/c", "npx.cmd", "--yes", "rea-agents@6.5.0", "mcp"]
```

L'ambiente specifica REA_ANALYSIS_PROVIDER, GHIDRA_INSTALL_DIR e JAVA_HOME. Non specifica npm_config_cache. Anche `.rea/mcp/ghidra.toml` ha questa struttura.

## Evidenze riproducibili

### Avvio della copia incompleta

```powershell
'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"diagnostic","version":"1"}}}' |
  node.exe 'C:\Users\e.rispoli\AppData\Local\npm-cache\_npx\ad9a3fdbcad992c6\node_modules\rea-agents\scripts\rea.mjs' mcp
```

Esito osservato, codice 1:

```text
.../rea-agents/dist/mcp/CdpConnection-BpDfz4MK.js:9
import WebSocket from "ws";
SyntaxError: The requested module 'ws' does not provide an export named 'default'
.../rea-agents/scripts/rea.mjs:55:29
Node.js v22.19.0
```

Entrambe le cache dichiarano ws 8.21.0. I rispettivi package.json risolvono l'import ESM a `./wrapper.mjs`.

| Cache, sotto _npx/ad9a3fdbcad992c6/node_modules/ws | Byte di wrapper.mjs | SHA-256 |
| --- | ---: | --- |
| AppData/Local/npm-cache | 0 | E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 |
| .tools/npm-cache | 554 | FE154662301FD558F935F9C217FCCBE7A7DAC02FF39E648A000589403FF27C7F |

Il file locale contiene `export default WebSocket;`. Quello nella cache utente non contiene testo.

### Avvio della copia locale

```powershell
$env:REA_ANALYSIS_PROVIDER = 'ghidra'
$env:GHIDRA_INSTALL_DIR = Join-Path $PWD '.tools\ghidra_12.1.4_PUBLIC'
$env:JAVA_HOME = Join-Path $PWD '.tools\jdk-21.0.12.1+1'
node.exe scripts/test-mcp.mjs .tools/npm-cache
```

Esito osservato, codice 0:

```text
PASS: direct Windows MCP registration, initialize and tools/list, 207 tools.
```

`scripts/test-mcp.mjs` invoca lo stesso comando Windows della registrazione, imposta npm_config_cache e npm_config_offline e verifica le risposte MCP. Il test verifica la presenza di binary_session e inspect_artifact.

### Limiti del confronto tramite npx nella sandbox

Il test con cache utente e offline termina con ENOTCACHED. La richiesta al registro npm non e disponibile nella cache HTTP. L'invocazione senza offline termina con ENOTFOUND per registry.npmjs.org nella sandbox. Questi sono ostacoli del percorso npm nel contesto di diagnosi; non sono stati attribuiti al processo desktop senza evidenza.

Il probe del comando registrato con stdin aperto e richiesta initialize non ha ricevuto risposta entro 15 secondi. Il processo di quel probe e stato terminato.

### Log desktop

`C:\Users\e.rispoli\AppData\Local\Codex\Logs\2026\10\15\codex-desktop-43240fad-f93b-432a-808d-aa9404f99b1c-40428-t0-i1-063208-0.log`, righe 5324 e 5490, registra il fallimento di rea-ghidra con `connection closed: initialize response`.

### Provider Ghidra

Doctor, eseguito dalla cache locale con i percorsi del profilo, riconosce Ghidra 12.1.4, il decompilatore x64 e il JDK completo 21.0.12.1. Il controllo nativo fallisce nella directory temporanea della sandbox con Win32 5, accesso negato, su `Read final handle path`.

Questo risultato non prova che il provider possa analizzare un binario nel processo desktop. Il test MCP dimostra soltanto l'avvio e il catalogo degli strumenti.

Ripetere doctor con TEMP e TMP impostati alla directory locale `.tools/verification-temp` produce ancora Win32 5 sul controllo `Read final handle path`. Cambiare soltanto la directory temporanea non risolve questo secondo vincolo nel contesto sandbox corrente.

## Raccomandazione

Impostare npm_config_cache alla cache locale gia verificata nell'ambiente di rea-ghidra e ripetere l'handshake dalla sessione Codex dopo il riavvio del server. npm_config_offline=true riproduce esattamente il percorso testato, ma richiede che il pacchetto resti disponibile nella cache e impedisce download automatici.

In alternativa, reinstallare REA in una cache dedicata e verificarla prima di aggiornare la registrazione. Non sostituire soltanto wrapper.mjs, perche non e stata verificata l'integrita delle altre dipendenze della cache utente.

Non e stata determinata la causa storica che ha lasciato il file vuoto. Non sono state modificate registrazioni, cache o dipendenze.

## Principi applicati

- Fix Root Causes. Riprodotto l'errore del caricamento ESM e verificato il file che lo provoca.
- Prove It Works. Eseguiti initialize e tools/list reali sulla copia alternativa, senza dedurre il funzionamento dai soli percorsi configurati.
