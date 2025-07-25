#!/bin/bash

# Marvin Setup Script - Sistema Unificato v8.2 FIXED
# Esegui con: bash setup.sh

echo "🚀 Installazione Sistema Marvin Unificato v8.2"
echo "================================================"

# Imposta la directory home di Marvin
MARVIN_HOME="$HOME/.marvin"

echo "📁 Creando directory structure..."
mkdir -p "$MARVIN_HOME"/{templates,temp}

echo "⚙️ Creando configurazione da config.example.json..."

# Copia il config.example.json esistente invece di duplicare
if [ -f "config.example.json" ]; then
    cp "config.example.json" "$MARVIN_HOME/config.json"
    echo "✅ Configurazione copiata da config.example.json"
else
    echo "❌ ERRORE: config.example.json non trovato nella directory corrente"
    echo "   Assicurati di eseguire setup.sh dalla directory root del progetto"
    exit 1
fi

echo "📝 Copiando template..."

# Copia i template esistenti invece di ricrearli
template_files=("idea.md" "vibe.md" "state.md" "decisions.md" ".gitignore")

for template in "${template_files[@]}"; do
    if [ -f "templates/$template" ]; then
        cp "templates/$template" "$MARVIN_HOME/templates/"
        echo "✅ Template copiato: $template"
    else
        echo "❌ ERRORE: templates/$template non trovato"
        exit 1
    fi
done

# Verifica dipendenze
echo "🔍 Verificando dipendenze..."
deps_missing=false

for cmd in jq curl git; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ $cmd non trovato"
        deps_missing=true
    else
        echo "✅ $cmd trovato ($(which $cmd))"
    fi
done

if [ "$deps_missing" = true ]; then
    echo ""
    echo "❌ Dipendenze mancanti. Installa con:"
    echo "   Ubuntu/Debian: sudo apt install jq curl git"
    echo "   macOS: brew install jq curl git"
    echo "   CentOS/RHEL: sudo yum install jq curl git"
    exit 1
fi

# Rende eseguibile lo script principale
if [ -f "marvin.sh" ]; then
    chmod +x marvin.sh
    echo "✅ Script marvin.sh reso eseguibile"
else
    echo "❌ ERRORE: marvin.sh non trovato nella directory corrente"
    exit 1
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

# Installa marvin globalmente
echo "🔧 Installando marvin globalmente..."
SCRIPT_PATH="$(pwd)/marvin.sh"

if [ -f "$SCRIPT_PATH" ]; then
    # Controlla se sudo è necessario
    if [ -w "/usr/local/bin" ]; then
        cp "$SCRIPT_PATH" /usr/local/bin/marvin
        chmod +x /usr/local/bin/marvin
    else
        sudo cp "$SCRIPT_PATH" /usr/local/bin/marvin
        sudo chmod +x /usr/local/bin/marvin
    fi
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
    exit 1
fi

# Test configurazione
echo "🧪 Testando configurazione..."
if [ -f "$MARVIN_HOME/config.json" ]; then
    if jq empty "$MARVIN_HOME/config.json" 2>/dev/null; then
        echo "✅ File config.json è JSON valido"
        
        default_ai=$(jq -r '.default_ai' "$MARVIN_HOME/config.json")
        echo "✅ Provider di default: $default_ai"
    else
        echo "❌ ERRORE: config.json contiene errori di sintassi"
        exit 1
    fi
else
    echo "❌ ERRORE: config.json non creato correttamente"
    exit 1
fi

echo ""
echo "✅ Installazione Marvin completata con successo!"
echo ""
echo "📋 PROSSIMI PASSI:"
echo "1. Ricarica il terminale:"
echo "   source $SHELL_RC"
echo ""
echo "2. Configura le API key in:"
echo "   $MARVIN_HOME/config.json"
echo ""
echo "3. Verifica installazione:"
echo "   marvin --help"
echo "   which marvin"
echo ""
echo "4. Crea il primo progetto:"
echo "   marvin new test-project"
echo "   cd test-project"
echo "   marvin chat"
echo ""
echo "🔑 CONFIGURAZIONE API NECESSARIA:"
echo "- Claude: Aggiungi api_key in ai_providers.claude.api_key"
echo "- OpenAI: Aggiungi api_key in ai_providers.openai.api_key"
echo "- Groq: Aggiungi api_key in ai_providers.groq.api_key (gratuita)"
echo "- Azure: Configura api_url e api_key in ai_providers.azure"
echo "- Ollama: Avvia servizio con 'ollama serve' (completamente locale)"
echo ""
echo "🛠️ UTILITY DISPONIBILI:"
echo "- Verifica sistema: bash ~/.marvin/utilities.sh check"
echo "- Debug progetto: bash utilities.sh analyze"
echo "- Fix config: bash ~/.marvin/utilities.sh fix-config"
echo ""
echo "🤖 Marvin è pronto per il vibe-coding!"