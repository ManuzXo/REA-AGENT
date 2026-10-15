# Installare i programmi esterni per REA

Installa i programmi per il workflow scelto nella [matrice delle funzionalità](rea-capabilities.md). I BAT di questo repository guidano la scelta dell'utente. Un link al produttore apre una pagina di download, mentre un installer scarica o installa software solo dopo la scelta prevista dal relativo script.

## Preparare Windows

1. Installa Node.js e npm dal [sito Node.js](https://nodejs.org/en/download).
2. Preferisci Node.js 24.15 o successivo della linea 24, oppure 26+ per coprire anche SQLite.
3. Apri PowerShell nella directory del repository.
4. Usa un'installazione Windows x64 per Ghidra e JADX.
5. Consulta l'help del BAT selezionato prima di passare parametri.

Le installazioni portatili gestite dal repository restano in `.tools/`, ignorata da Git. Non inserire nel repository licenze, token, software commerciali o campioni.

## Usare programmi gia presenti sul PC

Per collegare software esistente usa `setup.bat` e scegli **Collega software gia installato**. Scegli il profilo, lo strumento e il percorso effettivo. Non serve reinstallare il programma o spostarlo in `.tools/`. Il setup salva il percorso nel profilo e lo include nella successiva esportazione MCP. Segui gli [esempi di collegamento](setup-profiles.md#collegare-programmi-gia-installati) per Ghidra, Java, browser e altri strumenti.

I controlli delle ricevute degli installer si applicano soltanto al riutilizzo dei download gestiti dal repository. Il collegamento di installazioni esterne verifica i file richiesti senza richiedere queste ricevute. La compatibilita del motore resta da verificare con REA.

## Scegliere il BAT

I BAT `install-*`, eccetto Ghidra, richiamano `scripts/install-tools.ps1`. Per questi BAT l'opzione `-Mode Instructions` mostra le istruzioni senza eseguire l'installazione. Il modo predefinito `Install` mostra la proposta e richiede la scelta prevista dallo script. Ghidra usa `scripts/setup-ghidra.ps1` con i modi `Prompt`, `Rea`, `Install` ed `Existing`.

| BAT | Comportamento |
| --- | --- |
| `install-ghidra.bat` | Flusso dedicato Ghidra e JDK, con scelta installazione o percorsi esistenti. |
| `install-jadx.bat`, `install-apktool.bat`, `install-wabt.bat` | Download portatili versionati e verifica SHA-256. |
| `install-node.bat`, `install-java.bat`, `install-browser.bat`, `install-python.bat` | Installazione opzionale tramite WinGet. Verifica il pacchetto e i termini mostrati. |
| `install-adb.bat`, `install-rizin.bat`, `install-ida.bat`, `install-jeb.bat`, `install-hopper.bat` | Istruzioni e fonte ufficiale per installazioni manuali o con licenza. |
| `install-frida.bat`, `install-objdump.bat`, `install-gdb.bat`, `install-pwntools.bat` | Istruzioni per dipendenze, compatibilità e host richiesti. |
| `install-tshark.bat`, `install-capinfos.bat`, `install-mitmproxy.bat`, `install-sigrok.bat` | Istruzioni per analizzare registrazioni e configurare gli strumenti corrispondenti. |
| `install-binwalk.bat`, `install-unblob.bat`, `install-linux.bat` | Istruzioni per firmware e ambiente Linux. |
| `install-wakaru.bat`, `install-cutter.bat`, `install-ilspy.bat`, `install-pwndbg.bat` | Istruzioni per recupero JavaScript, ponte Cutter, decompilazione .NET opzionale e debugger pwndbg. |
| `install-kuna.bat` | Istruzioni per il provider documentato su upstream `main`, assente dal pin REA 6.5.0 verificato qui. |

```powershell
.\install-jadx.bat -Mode Instructions
.\install-jadx.bat
```

Le procedure manuali sono nelle sezioni sotto. La disponibilità di un BAT di istruzioni non dimostra che il programma supporti Windows.

## Ghidra e Java

Avvia `install-ghidra.bat` e scegli l'installazione portatile oppure i percorsi esistenti. L'installazione gestita usa Ghidra 12.1.4 e Temurin JDK 21 con SHA-256 fissati. La [guida Ghidra](setup-ghidra.md) descrive i requisiti e il recupero dagli errori.

```powershell
.\install-ghidra.bat -Mode Install
```

Nel profilo imposta `GHIDRA_INSTALL_DIR` alla directory di Ghidra e `JAVA_HOME` alla directory del JDK. Esegui `doctor --provider ghidra`. Il controllo verifica la configurazione, mentre la prima analisi di un tuo binario verifica l'uso effettivo del motore.

Il JDK 21 può servire anche JADX. Non occorre un secondo JDK se le versioni scelte sono compatibili.

Per installare soltanto Java senza scaricare Ghidra, avvia `install-java.bat`. Propone Temurin JDK 21 tramite WinGet. Riapri il terminale dopo l'installazione, verifica `java -version` e `javac -version` e imposta `JAVA_HOME` nel profilo alla directory effettivamente installata.

## JADX per APK

REA richiede il JAR [jadx-headless-mcp 0.7.1](https://github.com/1013503897/jadx-headless-mcp/releases/tag/v0.7.1). Il normale launcher della GUI JADX non sostituisce questo JAR.

1. Scarica `jadx-headless-mcp-0.7.1-all.jar` dalla release indicata.
2. Verifica il SHA-256 `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`.
3. Imposta `REA_JADX_MCP_JAR` al percorso assoluto del JAR.
4. Imposta `JAVA_HOME` a un JDK completo 17+, preferibilmente il JDK 21 usato dal setup Ghidra.
5. Esegui `doctor --provider jadx`.

```powershell
Get-FileHash 'C:\tools\jadx-headless-mcp-0.7.1-all.jar' -Algorithm SHA256
```

La [guida Android ufficiale](https://github.com/morluto/rea/blob/main/docs/android-analysis.md) pubblica URL, digest e limiti. Non occorrono un emulatore o l'Android SDK per l'analisi statica APK.

## Android Platform Tools e Apktool

Scarica adb da [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools). Estrai l'archivio e imposta `REA_ADB_PATH` al percorso assoluto di `adb.exe`. `inspect-adb-client` controlla il client senza contattare dispositivi. Per usare un dispositivo abilita il debug USB e approva il computer sul dispositivo. `list-adb-devices` può avviare il server adb.

Installa Apktool seguendo la [guida del progetto](https://apktool.org/docs/install/). REA accetta Apktool 2.7.0 o successivo. Su Windows conserva JAR e launcher BAT come indica il produttore, poi imposta `REA_APKTOOL_COMMAND` al BAT. Esegui `inspect-apktool-client`. La [guida REA alle risorse](https://github.com/morluto/rea/blob/main/docs/apktool-resource-analysis.md) descrive la decodifica.

## Browser, Electron e Frida

Usa un browser già installato, per esempio [Chrome](https://www.google.com/chrome/) o [Edge](https://www.microsoft.com/edge/download). Imposta `REA_BROWSER_EXECUTABLE` al suo eseguibile quando il workflow lo richiede. Per l'attach CDP avvia tu un profilo dedicato con `--remote-debugging-port=9222` e `--user-data-dir` separata. Passa l'endpoint loopback alla richiesta REA. Chiudi quel browser a fine analisi. La [guida CDP](https://github.com/morluto/rea/blob/main/docs/browser-observation.md) distingue osservazione e scenari che avviano e pilotano il browser.

Electron e V8 Inspector richiedono i relativi endpoint o un target esplicitamente scelto per uno scenario. Non installare un Electron generico per analizzare ogni applicazione. Usa la versione e il percorso del target autorizzato.

REA dichiara il binding Node [Frida](https://frida.re/docs/installation/) 17.23.2 come dipendenza opzionale. La disponibilità effettiva appare quando esegui un'operazione Frida. Un dispositivo remoto può richiedere Frida server compatibile e permessi aggiuntivi. Il server sul dispositivo si installa separatamente seguendo Frida. Non avviare target o caricare script durante il semplice setup.

## IDA, Hopper e JEB

Questi programmi richiedono l'installazione e gli eventuali diritti di licenza dell'utente.

| Programma | Prima | Dopo |
| --- | --- | --- |
| [IDA](https://hex-rays.com/ida-pro) | Installa la versione autorizzata. Scegli MCP legacy attached, supervisor headless o ponte nativo compatibile. | Salva la registrazione upstream in JSON e imposta `REA_IDA_MCP_CONFIG`. Esegui `doctor --provider ida`. Consulta la [guida REA IDA](https://github.com/morluto/rea/blob/main/docs/ida-provider.md). |
| [Hopper](https://www.hopperapp.com/) | Usa macOS o Linux supportato. Installa dal produttore oppure scegli l'installazione opzionale in `rea setup`. | Completa demo o attivazione nella GUI. Imposta `HOPPER_LAUNCHER_PATH` se necessario. Esegui `doctor --provider hopper`. |
| [JEB](https://www.pnfsoftware.com/jeb/) | Installa la copia autorizzata e avvia il server MCP dal client JEB. | Imposta `REA_JEB_MCP_URL`, di default `http://127.0.0.1:8425/mcp`. Esegui `inspect-jeb-client`. Consulta la [guida REA JEB](https://github.com/morluto/rea/blob/main/docs/jeb-analysis.md). |

Il ponte nativo IDA MCP 1.1.2 descritto upstream ascolta su tutte le interfacce. Prima di usarlo applica le restrizioni di rete indicate dalla guida IDA. Il profilo REA non modifica il listener del plugin.

## Utility offline e WASM

| Programma | Fonte | Configurazione e verifica |
| --- | --- | --- |
| GNU objdump | [GNU binutils](https://www.gnu.org/software/binutils/). | `REA_OBJDUMP_COMMAND` indica l'eseguibile. `list-objdump-architectures` mostra i target compilati nella build. |
| Rizin | [Release Rizin](https://github.com/rizinorg/rizin/releases). | `REA_RIZIN_COMMAND` indica l'eseguibile. Prima prova una lettura statica su un file autorizzato. Il debugger persistente REA richiede Linux. |
| Cutter | [Cutter](https://cutter.re/). | Installa anche il ponte Python REA compatibile v2 secondo la [guida REA](https://github.com/morluto/rea/blob/main/docs/reverse-engineering-tools.md#cutter-bridge). `REA_CUTTER_BRIDGE_DIR` seleziona la discovery locale. |
| WABT 1.0.42 | [Release WABT](https://github.com/WebAssembly/wabt/releases/tag/1.0.42). | Estrai la release per il sistema scelto e imposta `REA_WABT_BIN_DIRECTORY` alla directory degli eseguibili. Usa `inspect-wasm-artifact` su un modulo locale. |
| ILSpy CLI opzionale | [ILSpy](https://github.com/icsharpcode/ILSpy). | Installa `ilspycmd` e il runtime .NET richiesto da quella release. Imposta `REA_ILSPY_CMD_PATH`. La lettura statica CIL inclusa funziona senza ILSpy. |

## Preparare i workflow Linux

I BAT Windows non trasformano funzioni Linux in funzioni native Windows. Per questi workflow usa una VM Linux, un host Linux o WSL con REA e programmi installati nello stesso ambiente. I processi Linux usano percorsi Linux. Una registrazione MCP Windows deve avviare esplicitamente REA dentro quell'ambiente per usufruirne.

Installa `procps` o `procps-ng` per i controlli di proprietà dei processi e util-linux per `prlimit`. Mantieni gli estrattori richiesti da Unblob disponibili sul `PATH` Linux.

| Workflow | Programmi da installare nell'ambiente Linux | Variabili da configurare |
| --- | --- | --- |
| Firmware | [Binwalk](https://github.com/ReFirmLabs/binwalk) 3.1.x, [Unblob](https://unblob.org/) 26.6.x e relativi estrattori. | `REA_BINWALK_COMMAND`, `REA_UNBLOB_COMMAND`, `REA_FIRMWARE_PRLIMIT_COMMAND`. |
| Recupero JavaScript | [Wakaru](https://github.com/pionxzh/wakaru/releases/tag/v1.14.0) 1.14.0. | `REA_WAKARU_COMMAND` indica il binario Linux, non lo shim npm. `REA_JAVASCRIPT_PRLIMIT_COMMAND` seleziona `prlimit`. |
| Layout e crash ELF | Python in ambiente virtuale con [pwntools](https://docs.pwntools.com/) 4.15.0, pyelftools 0.33 e Unicorn 2.1.2. | `REA_PWNTOOLS_PYTHON` indica Python dell'ambiente virtuale. |
| Debug | [GDB](https://sourceware.org/gdb/) ed eventualmente [pwndbg](https://pwndbg.re/), oppure Rizin. | `REA_GDB_COMMAND`, `REA_PWNDBG_GDB`, `REA_PWNDBG_GDBINIT`, `REA_PWNDBG_VENV_PATH`, `REA_RIZIN_COMMAND`. Seleziona un TTY durevole nella richiesta. |
| PCAP | [Wireshark CLI](https://www.wireshark.org/download.html) 4.x con TShark e capinfos. | `REA_TSHARK_COMMAND`, `REA_CAPINFOS_COMMAND`, `REA_TSHARK_PRLIMIT_COMMAND`. |
| File mitmproxy | [mitmproxy](https://docs.mitmproxy.org/stable/overview/installation/) 12.2.3. | `REA_MITMDUMP_COMMAND` indica `mitmdump`. |
| Segnali logici | [sigrok-cli](https://sigrok.org/wiki/Sigrok-cli) 0.7.2 con libsigrokdecode. | `REA_SIGROK_COMMAND`, `REA_SIGROK_PRLIMIT_COMMAND`. |

Il modello `linux` documenta questi percorsi. Non prova la presenza di un ambiente Linux né installa una distribuzione. Le procedure del produttore restano necessarie quando il programma richiede dipendenze di sistema, privilegi o licenze.

## Preparare i workflow macOS

Per le funzioni dinamiche Apple usa macOS e gli strumenti di sviluppo richiesti dalla singola operazione. Scegli un target e un'azione autorizzati prima della cattura UI o delle chiamate native. I workflow PTY funzionano su Linux o macOS. Consulta la [guida processi REA](https://github.com/morluto/rea/blob/main/docs/process-capture.md).

## Verificare dopo l'installazione

Crea il profilo seguendo [setup-profiles.md](setup-profiles.md). Esegui i controlli specifici, genera la registrazione MCP e riconnetti il client. `doctor` non ha un selettore per ogni programma. Per gli adattatori opzionali usa `binary_session` e il comando di ispezione specifico. Non interpretare l'installazione riuscita come una verifica completa su un target reale.
