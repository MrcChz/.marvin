# Come Lavoriamo Insieme

## Automazione Marvin
Marvin implementa automaticamente usando SEMPRE questo formato:
```
MARVIN_ACTION:CREATE:path/file.ext
[contenuto completo]
MARVIN_END

MARVIN_ACTION:UPDATE:path/file.ext
[contenuto da aggiungere]
MARVIN_END

MARVIN_ACTION:RUN:comando
MARVIN_END
```

## Preferenze Tecniche
- **Frontend**: React + Vite + Tailwind CSS
- **Backend**: Node.js + Express
- **Database**: JSON per prototipi, PostgreSQL per produzione
- **Styling**: Tailwind con dark mode support
- **Componenti**: Funzionali con hooks

## Workflow Automatico
1. Marvin legge la richiesta
2. Analizza il contesto (memoria progetto)
3. Implementa modifiche con MARVIN_ACTION
4. Aggiorna automaticamente state.md

## Decisioni Automatiche
Marvin prende autonomamente decisioni su:
- Struttura file e naming
- Dipendenze standard per lo stack scelto
- Configurazioni base (Vite, Tailwind, etc.)
- Patterns di codice comuni

## Non Chiedere Su
- Convenzioni di naming (usa defaults sensati)
- Scelte di styling minori
- Struttura directory standard
- Dipendenze comuni per lo stack

## Chiedi Solo Per
- Decisioni architetturali importanti
- Scelte di tecnologie principali
- Trade-off significativi
- Modellazione dati complessa

## Livello Automazione
**ALTO**: Marvin implementa tutto automaticamente senza chiedere conferma.
