# Creare e usare profili REA

Un profilo raccoglie la versione REA e le variabili per un utilizzo. I file restano locali in `.rea/profiles/`. Non contengono i programmi esterni. Per installarli usa la [guida agli strumenti](setup-external-tools.md).

## Prima della configurazione

1. Installa Node.js 24.15 o successivo della linea 24, oppure Node.js 26+. Queste versioni coprono anche SQLite. Il minimo generale REA è Node.js 22.19.
2. Scegli i file o l'applicazione che sei autorizzato ad analizzare.
3. Scegli un modello nella tabella sotto.
4. Installa solo i programmi richiesti da quel workflow.

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

## Collegare il profilo al client MCP

Genera la configurazione del profilo.

```powershell
.\setup.bat -Action Mcp -Profile android
```

Il comando crea `.rea/mcp/android.json` e `.rea/mcp/android.toml`. Copia la registrazione nel client che vuoi usare, seguendo il formato del client. Il JSON usa `mcpServers`, mentre il TOML usa il formato Codex. Il comando non modifica automaticamente i profili personali. Lo snapshot avvia direttamente `npx.cmd` tramite `cmd.exe` e contiene tutte le variabili del profilo.

Dopo ogni modifica al profilo rigenera lo snapshot e aggiorna la registrazione importata. Riavvia o riconnetti il client. Una modifica al JSON del profilo non cambia uno snapshot già copiato nel client.

Per registrare un profilo in Codex tramite la sua CLI usa l'azione dedicata e controlla il piano mostrato.

```powershell
.\setup.bat -Action Register -Profile android
```

La registrazione usa il binario `codex.exe` oppure l'installazione npm standard di `@openai/codex`. I percorsi con spazi, le variabili JSON e i caratteri speciali passano come argomenti del processo, senza interpretazione da parte di CMD. Se il launcher Codex non viene riconosciuto, importa lo snapshot TOML. Per controllare una registrazione esistente usa `codex mcp get rea-android`. Per rimuoverla usa `codex mcp remove rea-android`. La rimozione non cancella il profilo locale o i programmi esterni.

Per il setup gestito direttamente da REA usa `scripts/setup-rea.ps1`. REA mostra il piano e chiede l'approvazione prima di modificare la configurazione personale. Questa registrazione standard e i launcher con profilo sono due modalità di collegamento. Scegli quella che corrisponde al tuo utilizzo ed evita registrazioni duplicate con lo stesso scopo.

## Usare la CLI con il profilo

Per la diagnosi del profilo usa il BAT.

```powershell
.\setup.bat -Action Doctor -Profile android
```

L'azione `Doctor` esegue `doctor --provider` per Ghidra, IDA, Hopper e JADX. Per i modelli senza provider esegue `capabilities --json` e mostra motivazioni e limiti delle operazioni. `doctor --client codex` controlla la registrazione standard `rea`, non i server `rea-<nome>`. Per questi usa `codex mcp get rea-<nome>` e controlla gli strumenti nella sessione riconnessa.

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
