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

Il setup prepara REA 6.5.0 tramite il lockfile in `config/rea-runtime/`, controlla il provider e salva il profilo locale `ghidra` con i percorsi verificati. Se la preparazione o il controllo falliscono, il profilo precedente resta invariato e MCP non viene registrato.

## Usa un profilo locale

Per piu configurazioni indipendenti, crea un profilo `native-ghidra` con `setup.bat`. Usa `-Action Link -Tool Ghidra` e `-Action Link -Tool Java` per scegliere installazioni gia presenti in qualunque directory accessibile del PC. Segui gli [esempi nella guida ai profili](setup-profiles.md#collegare-programmi-gia-installati), poi esegui `Doctor` e aggiorna MCP. Non occorre avviare l'installer per collegare questi percorsi.

Se devi prima scaricare i programmi, usa `.\install-ghidra.bat -Mode Install -SkipMcp`. Anche con `-SkipMcp` l'installer crea o aggiorna il profilo `ghidra` e controlla il provider. Per altri nomi di profilo, crea un profilo `native-ghidra` e collega le directory ottenute.

## Approva il collegamento MCP

Dopo la conferma del piano iniziale, il setup prepara il runtime, verifica Ghidra, esporta `.rea/mcp/ghidra.json` e `.rea/mcp/ghidra.toml`, poi registra `rea-ghidra` in Codex. Con `-SkipMcp` omette esportazione e registrazione. Per altri client, genera lo snapshot con `setup.bat -Action Mcp -Profile ghidra` e importa il JSON.

La registrazione usa i percorsi assoluti di Node e `.tools/rea-runtime/6.5.0/node_modules/rea-agents/scripts/rea.mjs`. Le variabili Ghidra e Java sono salvate nell'ambiente del server. Non usa `npx`, la cache npm globale o download durante l'handshake. Il bridge Java e incluso in REA.

Riavvia Codex dopo aver approvato. Apri una nuova sessione e controlla la registrazione.

```powershell
codex mcp get rea-ghidra
node scripts/test-mcp.mjs --snapshot .rea/mcp/ghidra.json
```

Per Claude Code registra lo stesso profilo in scope local per questo repository, poi riavvia Claude Code o usa `/mcp`.

```powershell
.\setup.bat -Action Register -Profile ghidra -Client claude
claude mcp get rea-ghidra
```

Un controllo dei file di configurazione non prova che il server sia collegato alla sessione corrente. Verifica anche che la nuova sessione esponga gli strumenti REA.

Per controllare il provider, usa il profilo locale.

```powershell
setup.bat -Action Doctor -Profile ghidra
node scripts/test-ghidra.mjs .rea/mcp/ghidra.json
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

Se REA fallisce all'avvio per una dipendenza incompleta, esegui `setup.bat -Action Runtime`. Il bootstrap verifica il runtime e lo ripara con un'installazione da lockfile prima di sostituirlo. La copia precedente resta in `.tools/rea-runtime/6.5.0.broken-<identificatore>`. Poi rigenera MCP con `setup.bat -Action Mcp -Profile ghidra`, aggiorna la registrazione con `setup.bat -Action Register -Profile ghidra` e riconnetti il client.

Se `doctor` restituisce Win32 5 in una sandbox dell'agente, ripeti lo stesso comando da un terminale Windows normale. I controlli nativi verificano handle, DACL e Job Object e possono essere impediti dalla sandbox. Non disabilitarli e non considerare sufficiente il solo catalogo MCP.

I percorsi salvati nella registrazione MCP sono assoluti. Dopo aver spostato il repository o le installazioni, riesegui il setup per aggiornare la registrazione.

## Verifica gli script

Esegui le verifiche senza scaricare Ghidra o modificare il profilo Codex.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-setup.ps1
```

I test degli installer usano archivi di prova e comandi esterni simulati. Il bootstrap verifica un handshake MCP reale. `test-ghidra.mjs` genera un PE x64 con la funzione `mov eax,42; ret`, lo apre con il provider `ghidra` e verifica il risultato decompilato. Non esegue il campione. Salva input, SHA-256 e risposte MCP in `.tools/ghidra-smoke/`.

## Consulta requisiti e limiti

Il provider REA per Ghidra su Windows è sperimentale. Richiede un host x64 e volumi locali NTFS per campioni e temporanei. Le operazioni supportate dipendono dalla release REA. Consulta [Windows Ghidra P0](https://github.com/morluto/rea/blob/main/docs/windows-ghidra-p0.md) prima dell'analisi.

La versione Ghidra è fissata alla famiglia accettata da REA. Non sostituirla automaticamente con l'ultima release Ghidra disponibile. Confronta i [requisiti del provider REA](https://github.com/morluto/rea/blob/main/docs/installation.md#ghidra) e le [note di Ghidra 12.1.4](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build).

Gli archivi Java provengono dai [rilasci ufficiali Eclipse Temurin 21](https://github.com/adoptium/temurin21-binaries/releases). Mantieni i file di licenza inclusi nei download.
