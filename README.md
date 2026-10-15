# REA workspace

Ambiente personale per configurare e usare [REA](https://github.com/morluto/rea). Il repository raccoglie profili, setup facoltativi e guide per tutte le famiglie di analisi documentate da REA. I programmi esterni, i campioni e le configurazioni personali restano locali.

## Parti da qui

1. Clona il repository. Apri [il catalogo delle funzionalita](docs/rea-capabilities.md) e scegli il tipo di analisi. Controlla il sistema operativo richiesto prima di installare software.
2. Avvia `setup.bat`. Il menu permette di creare piu profili, configurare i percorsi, controllare i provider ed esportare MCP. Per creare un profilo base senza installare strumenti:

   ```bat
   setup.bat -Action Create -Profile personale -Template builtin
   ```

3. Installa Node.js con npm. REA richiede Node 22.19+, 24.11+ oppure 26+. Per SQLite servono Node 24.15+ oppure 26+. `install-node.bat` propone l'installazione con WinGet, dopo conferma.
4. Usa gli strumenti compatibili gia installati sul PC. Per quelli mancanti, scegli i BAT `install-*.bat`. Per Ghidra, usa `install-ghidra.bat`. Per il solo JDK, usa `install-java.bat`. Segui [la preparazione degli strumenti](docs/setup-external-tools.md) e [la guida Ghidra](docs/setup-ghidra.md).
5. Collega i programmi al profilo dal menu di `setup.bat` oppure con `-Action Link -Profile personale -Tool Ghidra -Path 'C:\Tools\Ghidra'`. I percorsi possono essere esterni al repository. Segui [la guida ai profili](docs/setup-profiles.md) e usa `setup.bat -Action Doctor -Profile personale` per controllare il provider previsto dal modello oppure le capacita disponibili.
6. Per MCP, usa `setup.bat -Action Mcp -Profile personale`. Il setup prepara e verifica il runtime REA locale, poi genera lo snapshot JSON o TOML in `.rea/mcp/`. Importalo nel client. Con Codex CLI puoi registrarlo dopo conferma con `setup.bat -Action Register -Profile personale`, con Claude Code aggiungendo `-Client claude`.
7. Riavvia il client. Controlla gli strumenti esposti nella nuova sessione. Segui [la guida d'uso](docs/usage.md) per iniziare un'analisi.

La creazione di un profilo non scarica programmi. `Runtime`, `Mcp`, `Register`, `Doctor` e la CLI preparano REA in `.tools/rea-runtime/<versione>` quando manca. Il bootstrap usa `npm ci` con il lockfile versionato in `config/rea-runtime/` e una cache npm locale. Prima di pubblicare il runtime verifica versione, handshake e una chiamata MCP. Il comando registrato usa percorsi assoluti di Node e REA. L'avvio MCP non usa npm e non scarica pacchetti.

Per Ghidra da un clone nuovo, installa Node.js e avvia `install-ghidra.bat`. Scegli l'installazione dei programmi oppure collega Ghidra e JDK esistenti. Il setup controlla il provider, crea il profilo `ghidra`, esporta MCP e registra `rea-ghidra` in Codex dopo conferma. Per altri client importa `.rea/mcp/ghidra.json`. Segui [la guida Ghidra](docs/setup-ghidra.md).

Le registrazioni dei profili si chiamano `rea-<nome>` e contengono tutte le variabili configurate. `Client -Client codex` usa la stessa registrazione diretta. Per altri client, l'azione `Client` conserva il setup upstream, che gestisce una registrazione separata. Per usare il runtime locale anche con questi client, importa lo snapshot JSON. Abilita soltanto i server che vuoi usare nella sessione.

## Scegli una configurazione

Puoi creare piu profili dallo stesso modello. Per esempio `ghidra-lavoro` e `ghidra-personale` possono avere percorsi diversi.

| Modello | Utilizzo |
| --- | --- |
| `builtin` | JS/Electron statico, .NET, Go, Rust, Flutter, archivi, catture HTTP, SQLite ed EVM secondo i limiti host |
| `native-ghidra` | Binari nativi con Ghidra, Windows x64 sperimentale |
| `native-ida` | Binari nativi con IDA e MCP upstream |
| `native-hopper` | Hopper su macOS/Linux |
| `android` | JADX, adb, risorse con Apktool e JEB opzionale |
| `browser` | Browser CDP, osservazione web e sorgenti |
| `offline-tools` | WABT, GNU objdump e Rizin |
| `linux` | Firmware, crash, pacchetti, segnali e runtime su Linux |

I BAT e gli script PowerShell gestiscono Windows. Gli strumenti riservati a Linux/macOS hanno procedure dedicate nella guida. WSL e una macchina virtuale sono host distinti. Installa REA e le dipendenze al loro interno, usando percorsi e registrazioni di quell'host.

## Nomi e struttura

Un **client** e l'agente che si collega a MCP, per esempio Codex o Cursor. Un **provider** e un motore di analisi selezionato da REA. Un **helper** e un programma esterno usato da una specifica operazione. Un **profilo locale** contiene versione REA e variabili. Uno **snapshot MCP** e la copia del profilo importata nel client. Modificare il profilo non aggiorna automaticamente la copia registrata.

| Percorso | Contenuto |
| --- | --- |
| `config/rea.json` | Versione REA e modelli dei profili |
| `config/rea-runtime/`, `scripts/rea-runtime.ps1` | Dipendenze bloccate e bootstrap del runtime locale |
| `setup.bat`, `scripts/setup.ps1` | Menu generale e gestione profili |
| `rea-profile.bat`, `scripts/invoke-rea.ps1` | Comandi CLI con il profilo scelto |
| `install-ghidra.bat`, `scripts/setup-ghidra.ps1` | Installazione o collegamento Ghidra/JDK |
| `install-*.bat`, `scripts/install-tools.ps1` | Altri strumenti esterni e procedure del produttore |
| `scripts/setup-rea.ps1` | Setup ufficiale REA per un client |
| `.rea/profiles/`, `.rea/mcp/` | Profili ed esportazioni locali, ignorati da Git |
| `.tools/` | Strumenti portatili e dati di verifica locali, ignorati da Git |
| `docs/` | Catalogo, configurazione, utilizzo e analisi nativa |
| `analysis/samples/`, `analysis/captures/`, `analysis/tmp/` | Campioni, catture e dati temporanei locali |
| `analysis/reports/` | Rapporti testuali e decisioni verificabili |
| `AGENTS.md` | Istruzioni operative dell'agente |

## Versioni e controlli

REA e fissato alla versione `6.5.0` in `config/rea.json` e nel manifest e lockfile di `config/rea-runtime/`. Ogni profilo conserva la propria versione. Per aggiornare il runtime, aggiorna insieme questi file, verifica il nuovo pacchetto, modifica i profili interessati e rigenera MCP. Un profilo con una versione senza lockfile locale richiede la preparazione del relativo runtime. Le versioni e gli hash degli strumenti portatili sono fissati nei rispettivi manifest degli installer. Le installazioni WinGet seguono il pacchetto corrente e le condizioni proposte dal gestore.

Il ramo `main` upstream puo documentare capacita non ancora pubblicate. [Il catalogo locale](docs/rea-capabilities.md) distingue questo caso. `doctor` verifica registrazioni e prerequisiti. Non dimostra che ogni helper o formato funzioni con un campione reale.

Per verificare gli script senza installare programmi o modificare MCP:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-setup.ps1
```

I test degli installer simulano i download e i comandi esterni. La verifica reale di un motore richiede l'installazione scelta dall'utente e un campione autorizzato.

Per ripetere il bootstrap da una copia priva di runtime, profili e cache, esegui `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-clean-clone.ps1`. Il test richiede rete e npm, conserva le evidenze in `.tools/clean clone <identificatore>` e non modifica registrazioni utente. Per verificare Ghidra con una fixture generata e mai eseguita, usa `node scripts/test-ghidra.mjs .rea/mcp/ghidra.json`.

Il workflow `.github/workflows/windows-setup.yml` esegue i test su Windows e verifica il runtime e l'handshake da checkout pulito. La decompilazione Ghidra richiede la verifica locale descritta nella guida.

Usa REA su software che possiedi o che sei autorizzato a esaminare. Per le analisi native segui [il workflow con evidenze](docs/native-analysis.md). Le operazioni runtime possono avviare o modificare il processo selezionato. Consulta la guida prima di richiederle. I risultati inviati all'agente seguono anche le regole del provider del modello.
