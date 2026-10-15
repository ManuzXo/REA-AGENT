# Usare REA su una domanda concreta

Questa guida parte da un profilo già creato. Per prepararlo segui [setup-profiles.md](setup-profiles.md). Consulta [rea-capabilities.md](rea-capabilities.md) per host, dipendenze e inventario completo.

## Verificare la connessione

1. Esegui `setup.bat -Action Doctor -Profile NOME`.
2. Riconnetti il client dopo aver aggiunto la registrazione MCP.
3. Chiedi all'agente di chiamare `binary_session` senza aprire un target.
4. Leggi disponibilità, limiti e requisito del client per l'operazione scelta.

Usa campioni in `analysis/samples/` e salva i report di ogni programma in `analysis/reports/<nome-eseguibile>/`, una cartella ignorata da Git. Parti da un percorso assoluto e da una domanda verificabile. Chiedi di distinguere risultati osservati, inferenze e incognite.

## Analizzare un eseguibile con Ghidra, Hopper o IDA

Prima configura il provider. Apri un binario originale e specifica il provider quando più motori sono disponibili.

> Usa REA e il provider ghidra su `C:\targets\programma.exe`. Individua la funzione che costruisce l'URL di aggiornamento. Mostra stringhe, riferimenti, indirizzi e pseudocodice che sostengono la conclusione. Non eseguire il programma. Salva il rapporto in `analysis/reports/programma/aggiornamento.md`.

Dopo l'analisi esporta le Evidence utili e chiudi la sessione con `close_binary`. Per IDA attached apri prima lo stesso binario originale nella GUI. La presenza di un database IDA non sostituisce l'identità del binario originale.

## Analizzare JavaScript ed Electron senza avviarli

Il profilo `builtin` copre l'analisi statica.

> Analizza `C:\targets\app\resources\app.asar` con REA. Ricostruisci il flusso della funzione copia, dal renderer al preload e al main process. Elenca moduli, import e canali IPC osservati. Separa i collegamenti statici dalle chiamate runtime non osservate.

Per il recupero Wakaru usa il profilo Linux preparato. Chiedi un output nuovo e assente. Analizza poi i moduli recuperati senza eseguirli.

## Analizzare archivi, .NET, Go, Rust, Flutter e HarmonyOS

Usa `builtin` e scegli la lettura corrispondente.

| Input | Domanda iniziale per l'agente |
| --- | --- |
| Archivio o package | "Inventaria questo file, conserva percorsi e SHA-256 e identifica i componenti da esaminare. Estrai solo in una directory nuova." |
| Assembly .NET | "Ispeziona metadata e CIL. Individua il tipo che legge la configurazione e le dipendenze native dichiarate. Non caricare l'assembly." |
| Due build .NET | "Confronta i membri di queste build. Riporta identità, token locali alla build, cambiamenti osservati e corrispondenze inferite." |
| Binario Go | "Leggi versione del compilatore, moduli e impostazioni di build incorporati. Segnala i campi assenti." |
| Binario Rust | "Cerca i metadata cargo-auditable e riporta dipendenze e fonti registrate. Non dedurre metadata mancanti dai nomi delle stringhe." |
| APK Flutter | "Identifica build Flutter, snapshot Dart e librerie per ABI. Mostra gli hash. Distingui provenienza da sorgente Dart non recuperato." |
| HAP, HSP o App Pack HarmonyOS | "Crea un inventario e proietta il grafo HarmonyOS. Elenca manifest, Ark bytecode, risorse e librerie native. Non trattare ipotesi N-API come chiamate osservate." |
| App Apple | "Inventaria bundle, plist e risorse. Identifica l'eseguibile e i componenti da passare all'analisi nativa." |

Dopo l'inventario seleziona i componenti reali da approfondire. I grafi derivano dalle Evidence fornite e non dimostrano da soli il comportamento runtime.

## Analizzare APK e dispositivi Android

Per l'APK usa JADX. Per le risorse aggiungi Apktool. Per il dispositivo prepara adb e autorizza il collegamento.

> Ispeziona `C:\targets\Example.apk` con JADX. Elenca i componenti dichiarati e trova la classe che gestisce il login. Mostra il metodo e i riferimenti statici. Se esistono overload, elencali prima di sceglierne uno. Non installare né avviare l'APK.

> Controlla il client adb e poi elenca i dispositivi. Usa solo il seriale che indico. Elenca pacchetti e processi. Prima di installare, disinstallare, inviare file o avviare attività descrivi l'operazione richiesta.

Per JEB avvia il suo server MCP, poi chiedi `inspect_jeb_client` e `list_jeb_units`. Seleziona il progetto esplicitamente. Il solo endpoint valido non dimostra che il progetto sia aperto.

## Osservare siti, Electron e runtime JavaScript

Avvia un target di test con debug e profilo dedicati. L'attach CDP osserva il target esistente. Gli scenari Playwright ed Electron possono avviare il target ed eseguire azioni.

> Usa l'endpoint CDP `http://127.0.0.1:9222`. Elenca i target, poi osserva la pagina di test selezionata mentre eseguo una ricerca. Raccogli navigazione, script e metadati di rete. Non invocare strumenti WebMCP della pagina.

> Confronta queste due catture e gli screenshot. Riporta differenze osservate, normalizzazioni applicate e raccolte incomplete. Esporta gli script selezionati per l'analisi statica.

Per V8 Inspector seleziona il runtime e la durata della finestra di osservazione. Per uno scenario dichiara applicazione, URL e azioni. Dopo la cattura chiudi i processi che hai avviato manualmente.

## Ispezionare catture HTTP, PCAP e segnali

HAR e SAZ si leggono con `builtin`. PCAP, native mitmproxy e segnali richiedono i rispettivi strumenti. I workflow con `prlimit` richiedono Linux.

> Ispeziona questa cattura HAR o SAZ salvata. Cerca le richieste del flusso di login e mostra record sorgente, metodi, URL e risposte disponibili. Non contattare gli endpoint. Segnala payload mancanti e valori sensibili da escludere.

> Ispeziona il PCAP locale con TShark. Riporta DNS, SNI TLS e distribuzione dei protocolli. Per i campi selezionati conserva filtro e regole decode-as. Non iniziare catture di rete.

> Elenca i decoder sigrok che corrispondono a UART. Leggi opzioni e canali richiesti. Decodifica poi la registrazione con i parametri che indico e mostra annotazioni e intervalli dei campioni.

## Analizzare WASM, firmware, EVM e database

| Input | Preparazione | Richiesta iniziale |
| --- | --- | --- |
| WASM | WABT 1.0.42. | "Valida il modulo e mostra import, export e WAT. Non eseguire WASM. Confronta l'interfaccia con quest'altra build." |
| Firmware | Linux, Binwalk, Unblob, `prlimit` ed estrattori necessari. | "Individua le regioni. Estrai nella directory nuova che indico. Riporta regioni non estratte e dipendenze mancanti. Non eseguire i file estratti." |
| Bytecode EVM | Profilo Linux supportato. | "Ispeziona questo bytecode locale. Riporta selettori e offset osservati. Etichetta nomi e firme ricostruiti come inferenze." |
| SQLite | Node.js 24.15+ della linea 24, oppure 26+. | "Ispeziona schema e indici del database locale. Leggi solo le tabelle e le righe che seleziono. Conserva la relazione con lo snapshot WAL." |

## Usare debugger, Frida e catture di processi

Queste operazioni possono eseguire o modificare il target. Prepara prima un ambiente isolato e una richiesta esplicita per il target autorizzato.

> Sul target di test autorizzato, descrivi gli effetti della sessione Frida richiesta. Collega il processo selezionato e carica soltanto lo script indicato. Registra hash dello script, messaggi osservati e pulizia della sessione. Non terminare il target.

Per GDB e Rizin persistenti usa Linux e un TTY durevole scelto esplicitamente. Per layout ELF e crash registrati usa Python con pwntools. Un core dump registrato può essere analizzato senza rilanciare l'eseguibile.

Per la cattura PTY usa Linux o macOS. Definisci programma, argomenti, input e durata prima dell'avvio. Per UI e chiamate native Apple usa il workflow macOS appropriato.

## Concludere e conservare le prove

Chiedi all'agente di esportare le Evidence e annotare input, hash, provider e versione nel rapporto. Registra le domande rimaste aperte con gli strumenti delle incognite. Per una ricostruzione usa il ledger degli obblighi e valuta la copertura contro le prove disponibili. La somiglianza visiva o il pseudocodice da soli non dimostrano equivalenza.
