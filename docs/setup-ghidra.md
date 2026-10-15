# Installa Ghidra e collegalo a Codex

## Avvia il setup

Su Windows 10 o 11 x64, installa prima Node.js con npm. REA richiede Node.js 22.19+, 24.11+ oppure 26+, esclusi i rami 23 e 25.

Per il download automatico serve anche `tar.exe`, incluso nelle versioni aggiornate di Windows 10 e 11. Il setup lo usa per estrarre gli archivi con percorsi lunghi. Se manca, aggiorna Windows oppure estrai gli archivi ufficiali con uno strumento adatto e scegli installazioni esistenti.

Avvia `install-ghidra.bat` nella radice del repository. Il menu offre tre percorsi.

- Configura solo REA. Usa questa scelta se non vuoi installare Ghidra.
- Installa Ghidra e il JDK. Prima del download, controlla versioni, URL, destinazioni e conferma l'installazione.
- Collega Ghidra e un JDK esistenti. Indica le rispettive directory radice.

Puoi annullare dal menu. Clonare o aprire il repository non avvia alcuna installazione.

Lo script scarica gli archivi ufficiali di Ghidra 12.1.4 e Temurin JDK 21.0.12.1+1. Verifica i rispettivi SHA-256 prima di estrarli. Le directory di destinazione sono sotto `.tools/`, esclusa da Git. L'installazione non richiede privilegi amministrativi e non modifica il `PATH` globale.

Il setup imposta `GHIDRA_INSTALL_DIR` e `JAVA_HOME` nel proprio processo e controlla il provider con REA 6.5.0. Se il controllo fallisce, correggi il problema indicato prima di registrare MCP.

## Usa un profilo locale

Per piu configurazioni indipendenti, installa con `.\install-ghidra.bat -Mode Install -SkipMcp` oppure collega una copia esistente con `-Mode Existing -SkipMcp`. Crea poi un profilo `native-ghidra` con `setup.bat`, imposta `GHIDRA_INSTALL_DIR` e `JAVA_HOME` e segui [la guida ai profili](setup-profiles.md). L'installer Ghidra non crea automaticamente il profilo.

## Approva il collegamento MCP

Dopo il controllo del provider, REA mostra il piano per Codex. Controlla che includa i percorsi Ghidra e JDK selezionati, poi approva.

REA registra il proprio server MCP nel profilo utente Codex e salva i percorsi verificati nell'ambiente del server. Il piano di REA gestisce la conferma e la conservazione delle altre voci di configurazione. Non serve installare un secondo server MCP o un'estensione Ghidra. Il bridge Java è incluso in REA.

Riavvia Codex dopo aver approvato. Apri una nuova sessione e controlla la registrazione.

```powershell
npx.cmd --yes rea-agents@6.5.0 doctor --client codex --json
```

Un controllo dei file di configurazione non prova che il server sia collegato alla sessione corrente. Verifica anche che la nuova sessione esponga gli strumenti REA.

Per controllare il provider da un terminale separato, imposta i percorsi effettivi prima di eseguire `doctor`.

```powershell
$env:GHIDRA_INSTALL_DIR = 'C:\percorso\ghidra_12.1.4_PUBLIC'
$env:JAVA_HOME = 'C:\percorso\jdk-21.0.12.1+1'
npx.cmd --yes rea-agents@6.5.0 doctor --provider ghidra --json
```

## Usa installazioni esistenti

La directory Ghidra deve contenere `support\analyzeHeadless.bat` e `Ghidra\application.properties`. Usa Ghidra 12.1.x. La directory Java deve contenere `bin\java.exe` e `bin\javac.exe`. Per Ghidra 12.1.4 serve un JDK completo x64, versione 21 o superiore.

Puoi passare i percorsi dalla riga di comando.

```powershell
.\install-ghidra.bat -Mode Existing -GhidraPath 'C:\tools\ghidra_12.1.4_PUBLIC' -JavaPath 'C:\tools\jdk-21'
```

Per configurare solo REA, usa `.\install-ghidra.bat -Mode Rea`.

Per scegliere una directory diversa da `.tools/`, passa `-ToolsDirectory 'C:\percorso\strumenti'` alla modalità `Install`. Con `-SkipMcp`, il setup prepara e controlla il provider senza registrarlo in Codex. Il controllo può comunque scaricare REA tramite npm.

## Riprendi un setup interrotto

Riesegui `install-ghidra.bat`. Lo script riutilizza le installazioni complete nelle directory previste. Non estrae un archivio sopra un'installazione esistente.

Se una directory di destinazione esiste ma è incompleta, controllane il contenuto e spostala manualmente prima di riprovare. Se un hash non coincide, il setup rifiuta l'archivio. Non disabilitare il controllo. Verifica il download e il rilascio ufficiale.

Se REA segnala un problema del runtime nativo Windows, controlla i dettagli di `doctor`. Reinstallare Ghidra non risolve necessariamente problemi di filesystem, permessi o controlli nativi di REA.

Se REA fallisce all'avvio per una dipendenza npm incompleta, prova una cache separata prima di ripetere il setup. Per esempio, imposta `$env:npm_config_cache = Join-Path $PWD '.tools\npm-cache'` nel terminale che avvia `install-ghidra.bat`. La variabile vale per quel processo e i suoi figli.

I percorsi salvati nella registrazione MCP sono assoluti. Dopo aver spostato il repository o le installazioni, riesegui il setup per aggiornare la registrazione.

## Verifica gli script

Esegui le verifiche senza scaricare Ghidra o modificare il profilo Codex.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-setup.ps1
```

I test usano archivi di prova e comandi esterni simulati. Per verificare una vera installazione, esegui il setup e i controlli `doctor` descritti sopra.

## Consulta requisiti e limiti

Il provider REA per Ghidra su Windows è sperimentale. Richiede un host x64 e volumi locali NTFS per campioni e temporanei. Le operazioni supportate dipendono dalla release REA. Consulta [Windows Ghidra P0](https://github.com/morluto/rea/blob/main/docs/windows-ghidra-p0.md) prima dell'analisi.

La versione Ghidra è fissata alla famiglia accettata da REA. Non sostituirla automaticamente con l'ultima release Ghidra disponibile. Confronta i [requisiti del provider REA](https://github.com/morluto/rea/blob/main/docs/installation.md#ghidra) e le [note di Ghidra 12.1.4](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build).

Gli archivi Java provengono dai [rilasci ufficiali Eclipse Temurin 21](https://github.com/adoptium/temurin21-binaries/releases). Mantieni i file di licenza inclusi nei download.
