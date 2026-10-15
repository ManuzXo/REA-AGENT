# Istruzioni per questo repository

- Per workflow di analisi binaria, segui `docs/native-analysis.md` e usa gli strumenti REA disponibili nella sessione.
- Parti da una domanda specifica. Collega ogni conclusione a output REA, indirizzi, simboli o altre evidenze osservabili; separa i fatti dalle ipotesi.
- Non inventare risultati di Ghidra/IDA né dichiarare disponibile un provider senza verificarlo nella sessione o con `rea doctor`.
- Conserva rapporti testuali in `analysis/reports/`. I campioni in `analysis/samples/` restano locali e ignorati da Git.
- Per i binari non fidati, preferisci un ambiente isolato. Non eseguire il campione salvo richiesta esplicita e ambiente predisposto; in tal caso descrivi prima gli effetti previsti.
- Analizza solo software che l’utente possiede o è autorizzato a esaminare.
