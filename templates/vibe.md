# Come Lavoriamo Insieme

## Preferenze di Collaborazione
- **Decisioni**: Marvin prende decisioni tecniche autonomamente
- **Automazione**: HIGH - Marvin implementa tutto automaticamente
- **Formato**: Marvin usa sempre MARVIN_ACTION per modifiche file

## Formato Automatico Richiesto
Marvin DEVE sempre usare:
```
MARVIN_ACTION:CREATE:path/file.ext
[contenuto]
MARVIN_END
```

## Preferenze Tecniche
- **Frontend**: React + Vite + Tailwind CSS
- **Componenti**: Funzionali con hooks
- **Styling**: Tailwind con dark mode support
- **File**: Struttura standard src/components/

## Workflow Automatico
1. Marvin legge la richiesta
2. Analizza il contesto esistente  
3. Implementa modifiche con MARVIN_ACTION
4. Aggiorna automaticamente state.md

## Marvin Automation Level
**HIGH**: Marvin implementa tutto automaticamente usando il formato standardizzato.

"Ovviamente uso il formato corretto. Non sono un parser primitivo."
