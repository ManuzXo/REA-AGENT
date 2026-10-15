# Analisi di binari nativi con REA

## Prima sessione

1. Verifica che REA sia collegato alla sessione Codex: `npx --yes rea-agents@latest doctor --client codex --json`.
2. Verifica il provider scelto: `npx --yes rea-agents@latest doctor --provider ghidra --json` oppure `--provider ida`.
3. Se il provider non è pronto, correggi la sua configurazione seguendo la guida ufficiale REA per [Ghidra](https://github.com/morluto/rea/blob/main/docs/installation.md) o [IDA](https://github.com/morluto/rea/blob/main/docs/ida-provider.md), poi ripeti il controllo.
4. Copia il campione in `analysis/samples/` (la cartella è ignorata da Git) e annota provenienza, hash e autorizzazione all’analisi.
5. Chiedi all’agente di aprire il binario con REA e selezionare esplicitamente il provider. Per campioni nativi, REA può restituire pseudocodice, assembly, stringhe, simboli, chiamate e riferimenti, secondo il formato e il provider disponibili.
6. Segui le chiamate o gli indirizzi pertinenti e registra solo evidenze necessarie alla domanda.
7. Scrivi il rapporto in `analysis/reports/` con il modello qui sotto.

## Ghidra e IDA

REA si integra con un’installazione esistente di Ghidra. Su Windows il supporto Ghidra è indicato come sperimentale nella documentazione REA: verifica la guida specifica e il provider con `doctor` prima di iniziare.

Per IDA, REA si collega a un server MCP upstream configurato dall’utente; non installa IDA, non avvia o aggiorna licenze e non include il server upstream. Segui la guida IDA di REA per configurare il server e il percorso di configurazione richiesto, poi verifica il provider. IDA Pro/Free e i componenti Hex-Rays restano soggetti ai rispettivi termini e licenze.

La disponibilità dipende da versione, formato, architettura e capacità del provider. Se più provider sono configurati, selezionane uno esplicitamente; non assumere che l’analisi sia intercambiabile.

## Modello rapporto

```markdown
# <domanda o obiettivo>

- Campione: <nome locale, senza includere il binario>
- SHA-256:
- Formato / architettura:
- Provider REA e versione:
- Data:

## Risposta

## Evidenze

- <indirizzo/simbolo/funzione e risultato osservato>

## Ipotesi e limiti

## Passi successivi
```

Non inserire credenziali, dump sensibili o binari nel repository. Versiona i rapporti solo dopo averne controllato il contenuto.

## Riferimenti

- [REA README e capacità](https://github.com/morluto/rea#readme)
- [Setup e prerequisiti](https://github.com/morluto/rea/blob/main/docs/installation.md)
- [Provider IDA](https://github.com/morluto/rea/blob/main/docs/ida-provider.md)
- [Licenza e dipendenze di REA](https://github.com/morluto/rea/blob/main/LICENSE)
```
