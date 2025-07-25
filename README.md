# Marvin AI Assistant - Sistema Unificato v8.0

Un assistente AI per sviluppo software che mantiene memoria persistente del progetto e implementa automaticamente le modifiche richieste. Progettato per il "vibe-coding" - sessioni di sviluppo fluide e produttive.

*"Un assistente che capisce il contesto e implementa automaticamente"*

## 🚀 Caratteristiche Principali

- **Memoria Persistente**: Mantiene contesto completo tra sessioni tramite file strutturati
- **Automazione Totale**: Implementa automaticamente file, modifiche e comandi
- **Multi-Provider AI**: Supporta Claude, OpenAI, Groq, Ollama, Azure
- **Sistema di Decisioni**: Traccia e rispetta decisioni architetturali prese
- **Context-Aware**: Analizza la memoria del progetto per decisioni coerenti

## 📦 Installazione

### Prerequisiti

```bash
# Ubuntu/Debian
sudo apt install jq curl

# macOS
brew install jq curl

# CentOS/RHEL
sudo yum install jq curl
```

### Setup Completo

```bash
# 1. Scarica i file del sistema
git clone <repository> marvin-system
cd marvin-system

# 2. Esegui l'installazione
bash setup.sh

# 3. Ricarica il terminale
source ~/.bashrc  # o ~/.zshrc se usi Zsh

# 4. Verifica installazione
marvin --help
which marvin
```

### Configurazione API

Modifica `~/.marvin/config.json` con le tue API keys:

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
    }
  }
}
```

## 🏗️ Architettura Sistema

```
~/.marvin/                    # Directory home Marvin
├── config.json              # Configurazione providers AI
├── templates/                # Template per nuovi progetti
│   ├── idea.md              # Template obiettivi
│   ├── vibe.md              # Template collaborazione
│   ├── state.md             # Template stato tecnico
│   ├── decisions.md         # Template decisioni
│   └── .gitignore           # Template gitignore
└── temp/                     # Directory operazioni temporanee

<tuo-progetto>/
├── .marvin_memory/           # Memoria specifica del progetto
│   ├── idea.md              # Obiettivi e concept del progetto
│   ├── vibe.md              # Preferenze di collaborazione
│   ├── state.md             # Stato tecnico corrente
│   ├── decisions.md         # Log delle decisioni prese
│   └── session.log          # Storia delle conversazioni
├── src/                      # Il tuo codice
├── package.json             # Dipendenze
└── ...                      # Altri file del progetto
```

## 📋 Comandi Disponibili

### `marvin new <nome-progetto>`

Crea un nuovo progetto con memoria inizializzata:

```bash
marvin new my-react-app
cd my-react-app
```

**Cosa fa:**
- Crea la directory del progetto
- Inizializza `.marvin_memory/` con i template
- Configura `.gitignore` base
- Prepara il log di sessione

### `marvin chat`

Avvia la sessione interattiva (DEVE essere eseguito nella directory del progetto):

```bash
cd my-react-app
marvin chat

Tu: "Crea un'app React con Tailwind e dark mode"
# Marvin analizza la memoria e implementa automaticamente
```

**Funzionalità:**
- Carica automaticamente tutta la memoria del progetto
- Analizza la struttura file esistente  
- Implementa modifiche con formato `MARVIN_ACTION`
- Aggiorna `state.md` automaticamente
- Traccia la conversazione in `session.log`

### `marvin status`

Mostra overview dello stato progetto:

```bash
marvin status
```

**Output:**
- Concept principale dall'`idea.md`
- Stato tecnico da `state.md`
- Ultime attività da `session.log`

## 🤖 Sistema di Automazione

### Formato MARVIN_ACTION

Marvin implementa automaticamente usando questo formato standardizzato:

```
MARVIN_ACTION:CREATE:src/components/Button.jsx
import React from 'react';
export default function Button({ children, onClick }) {
  return (
    <button onClick={onClick} className="px-4 py-2 bg-blue-500 text-white rounded">
      {children}
    </button>
  );
}
MARVIN_END

MARVIN_ACTION:UPDATE:package.json
{
  "name": "my-react-app",
  "dependencies": {
    "react": "^18.0.0",
    "tailwindcss": "^3.0.0"
  }
}
MARVIN_END

MARVIN_ACTION:RUN:npm install tailwindcss
MARVIN_END
```

### Tipi di Azione

- **CREATE**: Crea nuovo file con contenuto completo
- **UPDATE**: Modifica file esistente (sostituisce tutto il contenuto)
- **RUN**: Esegue comando bash (solo comandi sicuri: npm, git, mkdir, etc.)

## 🧠 Sistema di Memoria

### idea.md - La Stella Polare
**Scopo**: Definisce cosa stai costruendo e perché

```markdown
# Nome Progetto

## Concetto Principale
Descrizione in 2-3 frasi di cosa stai costruendo

## Criteri di Successo  
- [ ] Funzionalità core implementata
- [ ] Performance accettabili
- [ ] UI/UX soddisfacente

## Contesto
- **Perché ora**: Motivazione del progetto
- **Time box**: Tempo dedicato
```

### vibe.md - Come Collaborare
**Scopo**: Definisce lo stile di collaborazione e automazione

```markdown
## Preferenze Tecniche
- **Frontend**: React + Vite + Tailwind CSS
- **Backend**: Node.js + Express
- **Database**: JSON per prototipi, PostgreSQL per produzione

## Livello Automazione
**ALTO**: Marvin implementa tutto automaticamente senza chiedere conferma
```

### state.md - Realtà Tecnica
**Scopo**: Foto istantanea dello stato attuale

```markdown
## Stack
- **Frontend**: React 18 + Vite ✅
- **Styling**: Tailwind CSS ✅  
- **Backend**: Express API ✅

## Cosa Funziona
- Struttura base componenti ✅
- Routing principale ✅

## Cosa Manca
- Autenticazione utenti ❌
- Database integration ❌

## Focus Attuale
Implementazione sistema autenticazione
```

### decisions.md - Decisioni Prese
**Scopo**: Traccia le decisioni importanti per evitare backtracking

```markdown
## Decisioni Architetturali
- **2024-01-15**: Scelto React invece di Vue per ecosystem più maturo
- **2024-01-16**: PostgreSQL invece di MongoDB per relazioni complesse

## Cose da NON Rivisitare
- Framework frontend (React confermato)
- Struttura database (schema definito)
```

## 🛠️ Providers AI Supportati

### Claude (Consigliato)
```json
{
  "claude": {
    "api_key": "sk-ant-your-key-here",
    "model": "claude-3-5-sonnet-20241022"
  }
}
```

### OpenAI
```json
{
  "openai": {
    "api_key": "sk-your-openai-key-here",
    "model": "gpt-4"
  }
}
```

### Groq (Veloce e Gratuito)
```json
{
  "groq": {
    "api_key": "gsk_your-groq-key-here",
    "model": "llama-3.1-70b-versatile"
  }
}
```

### Ollama (Completamente Locale)
```json
{
  "ollama": {
    "api_key": "none",
    "model": "codellama:13b"
  }
}
```

**Setup Ollama:**
```bash
# Installa Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Avvia il servizio
ollama serve

# Scarica un modello
ollama pull codellama:13b
```

### Azure OpenAI
```json
{
  "azure": {
    "api_url": "https://your-resource.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview",
    "api_key": "your-azure-key-here"
  }
}
```

## 💡 Esempi d'Uso

### Nuovo Progetto React
```bash
marvin new portfolio-site
cd portfolio-site
marvin chat

Tu: "Crea un portfolio React con dark mode, routing e sezioni About/Projects/Contact"
# Marvin implementa automaticamente:
# - Struttura componenti
# - React Router setup
# - Tailwind con dark mode
# - Componenti base per ogni sezione
```

### API Backend
```bash
marvin new api-server  
cd api-server
marvin chat

Tu: "Crea API Express con autenticazione JWT, middleware CORS e routes per users/posts"
# Marvin implementa:
# - Express server setup
# - JWT middleware
# - Database models
# - Route handlers
# - Error handling
```

### Sviluppo Iterativo
```bash
# Giorno 1
marvin chat
Tu: "Inizia con un form di login basilare"

# Giorno 2  
marvin chat
Tu: "Aggiungi validazione client-side e gestione errori"
# Marvin ricorda il form precedente e lo migliora
```

## 🔧 Utility di Manutenzione

Usa `utilities.sh` per operazioni di manutenzione:

```bash
# Verifica configurazione sistema
bash ~/.marvin/utilities.sh check

# Analizza salute progetto corrente
bash utilities.sh analyze

# Backup memoria progetto
bash utilities.sh backup

# Genera report completo
bash utilities.sh report
```

## 🚨 Risoluzione Problemi

### Comando `marvin` non trovato
```bash
# Verifica installazione
which marvin

# Se non trovato, ricontrolla MARVIN_HOME
echo $MARVIN_HOME

# Reinstalla se necessario
cd /path/to/marvin-system
bash setup.sh
```

### Errori API
```bash
# Testa configurazione
bash ~/.marvin/utilities.sh check

# Verifica API key in config.json
nano ~/.marvin/config.json

# Per Ollama, verifica servizio
curl http://localhost:11434/api/tags
```

### Memoria corrotta
```bash
# Backup attuale
bash utilities.sh backup

# Reset memoria
rm -rf .marvin_memory
marvin new temp-project
cp -r temp-project/.marvin_memory ./
rm -rf temp-project
```

### Performance Lente
- **Groq**: Più veloce per iterazioni rapide
- **Ollama**: Zero latency di rete, ma richiede GPU/CPU potenti
- **Claude**: Migliore qualità ma più lento

## 🎯 Best Practices

### Definisci Bene l'Idea Iniziale
```bash
marvin chat
Tu: "Aggiorna idea.md con: app di gestione task personali, criterio successo = gestire 100+ task con filtri avanzati, time box = 2 settimane"
```

### Usa Sessioni Focalizzate
```bash
# Sessione 1: Setup base
Tu: "Setup React + TypeScript + Tailwind con architettura componenti pulita"

# Sessione 2: Feature specifica  
Tu: "Implementa sistema di autenticazione con JWT"

# Sessione 3: UI polish
Tu: "Migliora UI con animazioni e responsive design"
```

### Sfrutta la Memoria
```bash
Tu: "Basandoti sulle decisioni precedenti in decisions.md, implementa il sistema di notifiche"
# Marvin consulterà decisions.md per decisioni coerenti
```

## ⚡ Vantaggi Chiave

1. **Zero Context Loss**: La memoria persiste tra sessioni
2. **Implementazione Automatica**: Meno copy-paste, più risultati  
3. **Decisioni Tracciate**: Non ripeti le stesse valutazioni
4. **Stack Consistency**: Mantiene coerenza tecnologica
5. **Rapid Prototyping**: Da idea a prototipo in minuti

## 🔒 Note di Sicurezza

- I comandi `RUN` sono limitati a: `npm`, `yarn`, `git`, `mkdir`, `touch`, `echo`, `npx`, `cd`, `ls`, `cat`
- Altri comandi vengono ignorati per sicurezza
- Le API key sono memorizzate in `~/.marvin/config.json` (non commitarlo!)

## 📄 Licenza

Sistema open source per uso personale e professionale.

---

*"Ovviamente funziona. Non è che avessi alternative migliori."* - Marvin
