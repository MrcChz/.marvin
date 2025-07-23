# Marvin AI Assistant - Sistema Unificato

Un assistente AI per vibe-coding che mantiene memoria del contesto tra sessioni e implementa automaticamente le modifiche.

*"Non è che io sia pessimista, è solo che tutte le alternative sono peggiori."*

## Caratteristiche Principali

- **Memoria Persistente**: Mantiene contesto tra sessioni tramite file strutturati
- **Automazione Completa**: Implementa automaticamente file e comandi
- **Multi-Provider**: Supporta Claude, OpenAI, Azure
- **Workflow Rapido**: Ottimizzato per prototipazione veloce
- **Vibe-Coding**: Progettato per sessioni di coding fluide e creative

## Installazione Rapida

```bash
# 1. Clona o scarica i file del sistema Marvin
# 2. Esegui il setup
bash setup.sh

# 3. Ricarica il terminale
source ~/.bashrc  # o ~/.zshrc

# 4. Configura le API key
nano ~/.marvin/config.json

# 5. Testa l'installazione
marvin new my-project
cd my-project
marvin chat
```

## Struttura del Sistema

```
~/.marvin/                    # Home directory Marvin
├── config.json              # Configurazione providers AI
├── templates/                # Template per nuovi progetti
│   ├── idea.md
│   ├── vibe.md
│   ├── state.md
│   ├── decisions.md
│   └── .gitignore
└── temp/                     # Directory temporanea

<progetto>/
├── .marvin_memory/           # Memoria del progetto
│   ├── idea.md              # Obiettivi e concept
│   ├── vibe.md              # Stile collaborazione
│   ├── state.md             # Stato tecnico attuale
│   ├── decisions.md         # Log decisioni prese
│   └── session.log          # Storia conversazioni
├── src/
└── ...
```

## Comandi Principali

### `marvin new <progetto>`
Crea un nuovo progetto con memoria inizializzata:
```bash
marvin new portfolio-website
cd portfolio-website
```

### `marvin chat`
Avvia la sessione interattiva con memoria caricata:
```bash
marvin chat
# Tu: "Crea un'app React con Tailwind"
# Marvin implementa automaticamente
```

### `marvin status`
Mostra lo stato corrente del progetto:
```bash
marvin status
# Visualizza idea, stato, ultima attivit�
```

## Formato di Automazione

Marvin usa un formato standardizzato per implementare automaticamente:

```
MARVIN_ACTION:CREATE:src/App.jsx
import React from 'react';
export default function App() {
  return <div>Hello World</div>;
}
MARVIN_END

MARVIN_ACTION:RUN:npm install tailwindcss
MARVIN_END
```

**Tipi di azione supportati:**
- `CREATE`: Crea nuovo file
- `UPDATE`: Modifica file esistente
- `RUN`: Esegue comando bash

## Configurazione AI Providers

Modifica `~/.marvin/config.json`:

```json
{
  "default_ai": "claude",
  "ai_providers": {
    "claude": {
      "api_key": "sk-ant-your-key-here",
      "model": "claude-3-5-sonnet-20241022"
    },
    "openai": {
      "api_key": "sk-your-openai-key-here",
      "model": "gpt-4"
    },
    "groq": {
      "api_key": "gsk_your-groq-key-here",
      "model": "llama-3.1-70b-versatile"
    },
    "ollama": {
      "api_key": "none",
      "model": "codellama:13b"
    },
    "azure": {
      "api_url": "https://your-resource.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview",
      "api_key": "your-azure-key-here"
    }
  }
}
```

### Provider Specifici

**Groq (Consigliato per velocità):**
- Registrati su [console.groq.com](https://console.groq.com)
- API key gratuita con rate limit generoso
- Velocità di risposta molto alta
- Modelli: `llama-3.1-70b-versatile`, `mixtral-8x7b-32768`

**Ollama (Consigliato per privacy):**
- Installa Ollama dal sito ufficiale
- Avvia il servizio: `ollama serve`
- Scarica un modello: `ollama pull codellama:13b`
- Completamente locale, nessuna API key necessaria

## Sistema di Memoria

### idea.md - La Stella Polare
- Concept principale del progetto
- Criteri di successo
- Contesto e motivazioni

### vibe.md - Come Collaborare
- Preferenze di automazione
- Stack tecnologico preferito
- Cosa Marvin decide autonomamente

### state.md - Realtà Tecnica
- Stack e architettura corrente
- Cosa funziona vs cosa manca
- Prossimi passi immediati

### decisions.md - Decisioni Prese
- Scelte architetturali importanti
- Trade-off accettati
- Cose da non rivisitare

## Esempi di Utilizzo

### Creazione App React
```bash
marvin new react-dashboard
cd react-dashboard
marvin chat

Tu: "Crea un dashboard React con dark mode e componenti riutilizzabili"
# Marvin implementa automaticamente struttura, Tailwind, componenti
```

### API Backend
```bash
marvin new api-server
cd api-server
marvin chat

Tu: "Crea un'API Express con autenticazione JWT e database PostgreSQL"
# Marvin configura Express, middleware, routes, database
```

### Sviluppo Iterativo
```bash
# Sessione 1
Tu: "Inizia con un form di login"
# Marvin crea componente login base

# Sessione 2 (giorno dopo)
marvin chat
Tu: "Aggiungi validazione e gestione errori al form"
# Marvin ricorda il contesto e migliora il form esistente
```

## Workflow Tipico

1. **Inizializzazione**: `marvin new progetto`
2. **Prima sessione**: Definisci l'idea e lo stack
3. **Sviluppo iterativo**: Sessioni `marvin chat` con implementazione automatica
4. **Memoria persistente**: Marvin ricorda tutto tra le sessioni
5. **Refinement**: Migliora basandosi sulle decisioni passate

## Vantaggi del Sistema

- **Zero Setup per Progetti**: Memoria e struttura automatiche
- **Continuità tra Sessioni**: Non perdi mai il contesto
- **Implementazione Automatica**: Meno copy-paste, più risultati
- **Decisioni Tracciate**: Storia delle scelte tecniche
- **Vibe-Coding Ottimizzato**: Flusso naturale e rapido

## Risoluzione Problemi

### Comando non trovato
```bash
# Aggiungi al tuo ~/.bashrc o ~/.zshrc:
export MARVIN_HOME="$HOME/.marvin"
alias marvin="/path/to/marvin.sh"
source ~/.bashrc
```

### Errore API
- Verifica le API key in `~/.marvin/config.json`
- Controlla la connessione internet
- Testa con `curl` l'endpoint API

### Memoria corrotta
```bash
# Ripristina template base
rm -rf .marvin_memory
marvin new temp-project
cp temp-project/.marvin_memory/* .marvin_memory/
rm -rf temp-project
```

## Dipendenze

- **bash** (4.0+)
- **jq** (parser JSON)
- **curl** (chiamate API)

Installa su Ubuntu/Debian:
```bash
sudo apt install jq curl
```

## Licenza

Sistema open source per uso personale e professionale.

---

*"Ovviamente funziona perfettamente. Non che ci fossero alternative."* - Marvin