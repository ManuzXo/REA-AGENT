# Creare e usare profili REA

Un profilo raccoglie la versione REA e le variabili per un utilizzo. I file restano locali in `.rea/profiles/`. Non contengono i programmi esterni. Per installarli usa la [guida agli strumenti](setup-external-tools.md).

## Prima della configurazione

1. Installa Node.js 24.15 o successivo della linea 24, oppure Node.js 26+. Queste versioni coprono anche SQLite. Il minimo generale REA è Node.js 22.19.
2. Scegli i file o l'applicazione che sei autorizzato ad analizzare.
3. Scegli un modello nella tabella sotto.
4. Usa i programmi compatibili gia presenti sul PC oppure installa quelli mancanti per quel workflow.

| Modello | Utilizzo |
| --- | --- |
| `builtin` | JavaScript statico, archivi, metadata .NET, Go, Rust, Flutter, HarmonyOS, SQLite e Evidence. |
| `native-ghidra` | Analisi nativa con Ghidra e JDK. |
| `native-ida` | Analisi nativa con IDA e registrazione MCP upstream. |
| `native-hopper` | Analisi nativa Hopper su Linux o macOS. |
| `android` | JADX, adb, Apktool e JEB opzionali. |
| `browser` | Browser, CDP, Electron e V8 Inspector. |
| `offline-tools` | GNU objdump, Rizin, WABT e altre utility fornite dall'utente. |
| `linux` | Firmware, PCAP, segnali, pwntools, debugger e recupero JavaScript. |

Un modello è una configurazione iniziale. La disponibilità reale dipende dal sistema e dai percorsi. Un profilo `android` può usare solo JADX senza installare adb o JEB.

## Creare il profilo

Apri un terminale nella directory del repository. Avvia `setup.bat` per il menu oppure usa un'azione esplicita.

```powershell
.\setup.bat -Action Create -Profile android -Template android
.\setup.bat -Action Set -Profile android -Key JAVA_HOME -Value 'C:\tools\jdk-21'
.\setup.bat -Action Set -Profile android -Key REA_JADX_MCP_JAR -Value 'C:\tools\jadx-headless-mcp-0.7.1-all.jar'
.\setup.bat -Action Doctor -Profile android
```

Sostituisci i percorsi con quelli installati. Usa nomi di profilo brevi, per esempio `android`, `ghidra-lavoro` o `web-test`. Puoi creare più profili dallo stesso modello.

Il file ha questa forma. I percorsi Windows nel JSON usano barre doppie.

```json
{
  "schemaVersion": 1,
  "reaVersion": "6.5.0",
  "template": "android",
  "description": "Analisi APK con JADX",
  "environment": {
    "JAVA_HOME": "C:\\tools\\jdk-21",
    "REA_JADX_MCP_JAR": "C:\\tools\\jadx-headless-mcp-0.7.1-all.jar"
  }
}
```

## Collegare programmi gia installati

Avvia `setup.bat` e scegli **Collega software gia installato**, poi indica il profilo, lo strumento e il percorso. Puoi usare directory esterne al repository, installazioni portatili o programmi installati dal produttore. Non occorre copiarli in `.tools/`.

Per Ghidra e Java usa le directory radice delle installazioni.

```powershell
.\setup.bat -Action Create -Profile ghidra-pc -Template native-ghidra
.\setup.bat -Action Link -Profile ghidra-pc -Tool Ghidra -Path 'C:\Program Files\Ghidra\ghidra_12.1.4_PUBLIC'
.\setup.bat -Action Link -Profile ghidra-pc -Tool Java -Path 'C:\Program Files\Eclipse Adoptium\jdk-21'
.\setup.bat -Action Doctor -Profile ghidra-pc
.\setup.bat -Action Mcp -Profile ghidra-pc
```

Sostituisci i percorsi di esempio con quelli presenti sul PC. Ometti `-Path` per inserirlo al prompt. Per cambiare installazione ripeti `Link` sullo stesso profilo. Gli altri profili conservano i propri percorsi.

`Link` controlla il percorso e i file richiesti, poi salva il percorso assoluto nel profilo. Non richiede ricevute dell'installer del repository. Non scarica programmi e non avvia il software selezionato. La verifica dei file non dimostra la disponibilita del provider. Esegui anche `Doctor` e verifica gli strumenti nella sessione MCP riconnessa.

Per gli altri strumenti seleziona il componente richiesto da REA.

| Strumento | Percorso da indicare |
| --- | --- |
| `Jadx` | JAR headless MCP compatibile, non il launcher della GUI JADX. |
| `Wabt` | Directory `bin` contenente `wasm2wat.exe`, `wasm-objdump.exe` e `wasm-validate.exe`. |
| `Apktool` | Launcher del comando, per esempio `apktool.cmd`, non il solo JAR. |
| `Adb` | File `adb.exe`. |
| `Browser` | Eseguibile Chrome o Edge. |
| `Rizin` | Eseguibile Rizin. |
| `Ilspy` | Eseguibile `ilspycmd`. |
| `Ida` | File JSON di registrazione MCP upstream, non `ida.exe`. |
| `Cutter` | Directory del bridge REA Cutter, non la directory dell'applicazione. |

Per esempio, collega una copia di Platform-Tools e il browser gia presenti sul PC.

```powershell
.\setup.bat -Action Link -Profile android -Tool Adb -Path 'D:\Android SDK\platform-tools\adb.exe'
.\setup.bat -Action Create -Profile web -Template browser
.\setup.bat -Action Link -Profile web -Tool Browser -Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
```

Node.js e npm gia disponibili nel `PATH` possono essere usati direttamente. La dipendenza Frida e costituita dai binding Node caricati da REA. Per JEB configura l'endpoint del server MCP gia avviato con `Set`, per esempio `-Key REA_JEB_MCP_URL -Value 'http://127.0.0.1:8425/mcp'`. Gli strumenti riservati a Linux o macOS vanno configurati sull'host supportato con i percorsi di quell'host. Consulta la [guida agli strumenti](setup-external-tools.md).

Dopo `Link`, rigenera lo snapshot con `Mcp` oppure aggiorna la registrazione con `Register`, poi riconnetti il client. Una registrazione gia importata conserva i percorsi precedenti finche non la aggiorni.

## Collegare il profilo al client MCP

Genera la configurazione del profilo.

```powershell
.\setup.bat -Action Mcp -Profile android
```

Il comando prepara e verifica REA nella directory locale `.tools/rea-runtime/<versione>`, poi crea `.rea/mcp/android.json` e `.rea/mcp/android.toml`. La prima preparazione richiede rete e npm. Copia la registrazione nel client che vuoi usare. Il JSON usa `mcpServers`, mentre il TOML usa il formato Codex. Lo snapshot avvia Node direttamente con il percorso assoluto del runtime verificato e contiene tutte le variabili del profilo. L'avvio MCP non scarica dipendenze.

Dopo ogni modifica al profilo rigenera lo snapshot e aggiorna la registrazione importata. Riavvia o riconnetti il client. Una modifica al JSON del profilo non cambia uno snapshot già copiato nel client.

Per registrare un profilo in Codex tramite la sua CLI usa l'azione dedicata e controlla il piano mostrato.

```powershell
.\setup.bat -Action Register -Profile android
```

La registrazione usa il binario `codex.exe` oppure l'installazione npm standard di `@openai/codex`. I percorsi con spazi, le variabili JSON e i caratteri speciali passano come argomenti del processo, senza interpretazione da parte di CMD. Se il launcher Codex non viene riconosciuto, importa lo snapshot TOML. Per controllare una registrazione esistente usa `codex mcp get rea-android`. Per rimuoverla usa `codex mcp remove rea-android`. La rimozione non cancella il profilo locale o i programmi esterni.

Per Claude Code aggiungi `-Client claude`.

```powershell
.\setup.bat -Action Register -Profile android -Client claude
```

La registrazione usa `claude.exe` oppure l'installazione npm standard di `@anthropic-ai/claude-code` ed esegue `claude mcp add-json --scope local`. La voce resta nella configurazione privata di Claude Code per questo repository e non finisce in un `.mcp.json` versionato, perché contiene percorsi assoluti locali. Un server `rea-<nome>` già presente in scope local viene sostituito. Per controllarla usa `claude mcp get rea-android`, per rimuoverla `claude mcp remove rea-android -s local`. Riavvia Claude Code o riconnetti il server con `/mcp`.

Con `-Yes` puoi autorizzare esplicitamente la registrazione senza il prompt, per esempio `setup.bat -Action Register -Profile android -Yes`. Per gli altri client usa gli snapshot se vuoi mantenere il runtime locale. `Client` con `codex` o `claude_code` riusa la registrazione diretta del profilo. Per gli altri client conserva il setup upstream e la sua registrazione separata.

Per preparare o riparare soltanto il runtime usa `setup.bat -Action Runtime`. Il setup verifica la copia esistente prima di riutilizzarla. Se deve sostituirla, conserva quella precedente in una directory `.broken-<identificatore>` e pubblica la nuova soltanto dopo i controlli. Non cancella la cache npm globale.

## Usare la CLI con il profilo

Per la diagnosi del profilo usa il BAT.

```powershell
.\setup.bat -Action Doctor -Profile android
```

L'azione `Doctor` esegue `doctor --provider` per Ghidra, IDA, Hopper e JADX. Per i modelli senza provider esegue `capabilities --json` e mostra motivazioni e limiti delle operazioni. `doctor --client codex` controlla la registrazione standard `rea`, non i server `rea-<nome>`. Per questi usa `codex mcp get rea-<nome>` oppure `claude mcp get rea-<nome>` e controlla gli strumenti nella sessione riconnessa.

Per argomenti multipli usa PowerShell, che mantiene l'array degli argomenti.

```powershell
.\scripts\invoke-rea.ps1 -Profile android -Command inspect-android-package -ReaArguments @('C:\targets\Example.apk', '--json')
.\scripts\invoke-rea.ps1 -Profile android -Command doctor -ReaArguments @('--provider', 'jadx', '--json')
```

Le variabili del profilo valgono per il processo lanciato. Le impostazioni persistenti di Windows restano indipendenti. Il profilo non installa una sandbox. Per campioni non fidati prepara un ambiente isolato.

## Dopo la configurazione

1. Esegui la diagnosi del profilo.
2. Riconnetti il client MCP.
3. Chiedi `binary_session` senza target per conoscere strumenti e limiti effettivi.
4. Inizia con una domanda specifica nella [guida d'uso](usage.md).

Per aggiornare REA scegli e verifica una nuova versione, modifica il profilo, poi riconnetti il client. Il catalogo di `main` può precedere la versione npm. Conserva i report in `analysis/reports/` e i campioni locali in `analysis/samples/`.
