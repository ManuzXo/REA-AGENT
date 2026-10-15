# Estensione del setup REA

## Criterio di completamento

Ogni famiglia di funzionalita documentata da REA deve avere una voce nel catalogo, requisiti, limiti del sistema operativo e una guida. Il setup deve consentire configurazioni locali distinte, installazione facoltativa degli strumenti esterni e collegamento MCP con tutte le variabili del profilo. Il setup ufficiale resta disponibile per registrazione standard e istruzioni agente. Nessun motore esterno viene installato sul computer durante lo sviluppo.

## Fasi

1. Leggere i principi Poteto Mode e verificare il setup esistente.
2. Frame. Confrontare la documentazione upstream e il pacchetto npm fissato.
3. Design the workflow. Confrontare due strutture del setup e definire catalogo, profili e installatori.
4. Run the loop. Implementare unita verificabili. Prima catalogo e profili, poi installatori e integrazione.
5. Keep the audit trail. Registrare decisioni ed evidenze nel file TSV accanto a questo piano.
6. Verify and hand back. Eseguire test, revisione indipendente e verifica delle guide.

## Checkpoint di lavoro

La ricerca upstream e la proposta architetturale sono indipendenti. Due agenti lavorano in sola lettura. Un solo autore modifica gli script finche i confini dei file non sono stabiliti. I test esistenti sono la base di confronto. Il catalogo deve evitare di duplicare versioni e nomi di variabili nelle condizioni del menu.
