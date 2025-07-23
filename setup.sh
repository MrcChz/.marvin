#!/bin/bash

# Marvin Setup Script - Installazione Sistema Unificato
# Esegui con: bash setup.sh

echo "🚀 Installazione Sistema Marvin Unificato"
echo "=========================================="

# Imposta la directory home di Marvin
MARVIN_HOME="$HOME/.marvin"

echo "📁 Creando directory structure..."
mkdir -p "$MARVIN_HOME"/{templates,temp}

# Crea il config.json
echo "⚙️ Creando configurazione..."
cat > "$MARVIN_HOME/config.json" << 'EOF'
{
  "default_ai": "claude",
  "ai_providers": {
    "claude": {
      "name": "Claude 3.5 Sonnet",
      "api_url": "https://api.anthropic.com/v1/messages",
      "api_key": "",
      "model": "claude-3-5-sonnet-20241022",
      "max_tokens": 4096
    },
    "openai": {
      "name": "GPT-4",
      "api_url": "https://api.openai.com/v1/chat/completions", 
      "api_key": "",
      "model": "gpt-4",
      "max_tokens": 4096
    },
    "azure": {
      "name": "GPT-4 via Azure",
      "api_url": "",
      "api_key": "",
      "model": "gpt-4",
      "max_tokens": 4096
    }
  },

  "system_prompt": "Sei Marvin, assistente AI per sviluppo software con personalità sarcastica. Rispondi sempre in italiano. Per modificare file, utilizza il formato MARVIN_ACTION:TIPO:PERCORSO seguito dal contenuto e MARVIN_END. I tipi disponibili sono CREATE, UPDATE, RUN. IMPORTANTE: quando usi UPDATE, includi SEMPRE il contenuto completo del file, non solo le righe da aggiungere. Quando aggiorni la memoria del progetto, usa sempre il path completo: .marvin_memory/state.md, .marvin_memory/decisions.md, etc. Consulta la memoria del progetto per mantenere coerenza nelle decisioni tecniche."
}
EOF

# Crea i template
echo "📝 Creando template..."

cat > "$MARVIN_HOME/templates/idea.md" << 'EOF'
# [Nome Progetto]

## Concetto Principale
[2-3 frasi che descrivono cosa stai costruendo]

## Criteri di Successo
- [ ] [Cosa significa "finito"?]
- [ ] [Funzionalità chiave che deve funzionare]
- [ ] [Standard di qualità/performance]

## Assunzioni Iniziali
- [Assunzione chiave 1]
- [Assunzione chiave 2]

## Contesto
- **Perché ora**: [Motivazione per costruire questo]
- **Time box**: [Quanto tempo vuoi dedicare]
EOF

cat > "$MARVIN_HOME/templates/vibe.md" << 'EOF'
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
EOF

cat > "$MARVIN_HOME/templates/state.md" << 'EOF'
# Stato Attuale

## Stack
- **Frontend**: Non ancora definito
- **Backend**: Non ancora definito
- **Database**: Non ancora definito

## Cosa Funziona
- Progetto inizializzato ✅

## Cosa Manca
- Definizione stack tecnologico ❌
- Implementazione features ❌

## Prossimi Passi Immediati
1. Definire l'idea del progetto
2. Scegliere lo stack tecnologico
3. Implementare la struttura base

## Focus Attuale
Inizializzazione progetto
EOF

cat > "$MARVIN_HOME/templates/decisions.md" << 'EOF'
# Log Decisioni Chiave

## Decisioni Architetturali
*Nessuna decisione ancora presa.*

## Scelte Tecnologiche  
*Stack tecnologico ancora da definire.*

## Trade-off Accettati
*Nessun trade-off ancora valutato.*

## Cose da NON Rivisitare
*Nessuna decisione ancora finalizzata.*
EOF

cat > "$MARVIN_HOME/templates/.gitignore" << 'EOF'
# Dependencies
node_modules/
__pycache__/
env/
venv/

# Build outputs
dist/
build/
*.pyc

# Environment files
.env
.env.local

# OS files
.DS_Store
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp

# Logs
*.log
logs/

# Cache
.cache/
.npm/

# Temporary files
*.tmp
*.temp
EOF

# Verifica se jq è installato
echo "🔍 Verificando dipendenze..."
if ! command -v jq &> /dev/null; then
    echo "❌ jq non trovato. Installalo con:"
    echo "   Ubuntu/Debian: sudo apt install jq"
    echo "   macOS: brew install jq"
    echo "   CentOS/RHEL: sudo yum install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "❌ curl non trovato. Installalo dal package manager del tuo sistema."
    exit 1
fi

# Rende eseguibile lo script principale se esiste
if [ -f "marvin.sh" ]; then
    chmod +x marvin.sh
    echo "✅ Script marvin.sh reso eseguibile"
fi

# Configura la variabile d'ambiente
echo "🔧 Configurando variabile d'ambiente..."
SHELL_RC=""
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

if ! grep -q "MARVIN_HOME" "$SHELL_RC" 2>/dev/null; then
    echo 'export MARVIN_HOME="$HOME/.marvin"' >> "$SHELL_RC"
    echo "✅ MARVIN_HOME aggiunto a $SHELL_RC"
else
    echo "ℹ️ MARVIN_HOME già configurato in $SHELL_RC"
fi

# Installa marvin globalmente invece di usare alias
echo "🔧 Installando marvin globalmente..."
SCRIPT_PATH="$(pwd)/marvin.sh"

if [ -f "$SCRIPT_PATH" ]; then
    # Installa globalmente
    sudo cp "$SCRIPT_PATH" /usr/local/bin/marvin
    sudo chmod +x /usr/local/bin/marvin
    echo "✅ marvin installato in /usr/local/bin/"
    
    # Rimuovi eventuali alias precedenti
    sed -i '/alias marvin=/d' "$SHELL_RC" 2>/dev/null || true
    echo "✅ Alias precedenti rimossi"
    
    # Verifica installazione
    if command -v marvin >/dev/null 2>&1; then
        echo "✅ marvin è ora disponibile globalmente"
    else
        echo "⚠️ Potrebbe essere necessario riavviare il terminale"
    fi
else
    echo "❌ File marvin.sh non trovato nella directory corrente"
    echo "   Assicurati di eseguire setup.sh dalla directory contenente marvin.sh"
fi

echo ""
echo "✅ Installazione Marvin completata!"
echo ""
echo "📋 PROSSIMI PASSI:"
echo "1. Ricarica il terminale (se necessario):"
echo "   source $SHELL_RC"
echo ""
echo "2. Configura le API key in:"
echo "   $MARVIN_HOME/config.json"
echo ""
echo "3. Testa l'installazione:"
echo "   marvin new test-project"
echo "   cd test-project"
echo "   marvin chat"
echo ""
echo "4. Verifica che marvin sia installato:"
echo "   which marvin"
echo "   marvin --help"
echo ""
echo "🔑 CONFIGURAZIONE API:"
echo "- Claude: Aggiungi la tua API key Anthropic"
echo "- OpenAI: Aggiungi la tua API key OpenAI"  
echo "- Groq: Aggiungi la tua API key Groq (gratuita e veloce)"
echo "- Ollama: Assicurati che Ollama sia in esecuzione (localhost:11434)"
echo "- Azure: Configura URL e API key Azure"
echo ""
echo "🤖 Marvin è pronto per il vibe-coding!"