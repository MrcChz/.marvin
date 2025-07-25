#!/bin/bash

# utilities.sh - Script di utility per manutenzione Marvin - FIXED v8.2

MARVIN_HOME="${MARVIN_HOME:-$HOME/.marvin}"
PROJECT_MEMORY=".marvin_memory"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Funzione: Verifica configurazione COMPLETA
check_config() {
    echo_info "Verifica configurazione Marvin v8.2"
    echo "======================================"
    
    # Controlla MARVIN_HOME
    if [ -z "$MARVIN_HOME" ]; then
        echo_error "MARVIN_HOME non impostato"
        echo "Aggiungi al tuo ~/.bashrc o ~/.zshrc:"
        echo 'export MARVIN_HOME="$HOME/.marvin"'
        return 1
    else
        echo_success "MARVIN_HOME: $MARVIN_HOME"
    fi
    
    # Controlla se la directory esiste
    if [ ! -d "$MARVIN_HOME" ]; then
        echo_error "Directory MARVIN_HOME non esistente"
        echo "Esegui: mkdir -p $MARVIN_HOME"
        return 1
    fi
    
    # Controlla file config
    if [ ! -f "$MARVIN_HOME/config.json" ]; then
        echo_error "File config.json non trovato"
        if [ -f "$MARVIN_HOME/../config.example.json" ]; then
            echo_warning "Trovato config.example.json, lo copio in config.json"
            cp "$MARVIN_HOME/../config.example.json" "$MARVIN_HOME/config.json"
            echo_success "config.json creato da template"
        else
            echo_error "Crea il file config.json da config.example.json"
            return 1
        fi
    else
        echo_success "File config.json presente"
    fi
    
    # Controlla validità JSON
    if jq empty "$MARVIN_HOME/config.json" 2>/dev/null; then
        echo_success "config.json è JSON valido"
    else
        echo_error "config.json contiene errori di sintassi"
        echo "Errore dettaglio:"
        jq . "$MARVIN_HOME/config.json" 2>&1 | head -3
        return 1
    fi
    
    # Controlla API key
    local default_ai=$(jq -r '.default_ai' "$MARVIN_HOME/config.json")
    echo_info "Provider di default: $default_ai"
    
    local api_key=$(jq -r ".ai_providers.$default_ai.api_key" "$MARVIN_HOME/config.json")
    if [ "$api_key" = "" ] || [ "$api_key" = "null" ]; then
        echo_warning "API key per $default_ai non configurata"
        echo "Modifica il file $MARVIN_HOME/config.json"
    else
        echo_success "API key per $default_ai configurata"
        
        # Test specifico per Ollama
        if [ "$default_ai" = "ollama" ]; then
            if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                echo_success "Ollama service è raggiungibile"
            else
                echo_warning "Ollama service non raggiungibile (localhost:11434)"
                echo "Avvia Ollama con: ollama serve"
            fi
        fi
    fi
    
    # Controlla dipendenze
    echo ""
    echo_info "Dipendenze sistema:"
    local deps_ok=true
    for cmd in jq curl git; do
        if command -v $cmd >/dev/null 2>&1; then
            echo_success "$cmd installato ($(which $cmd))"
        else
            echo_error "$cmd non trovato"
            deps_ok=false
        fi
    done
    
    if [ "$deps_ok" = false ]; then
        echo ""
        echo_error "Installa le dipendenze mancanti:"
        echo "Ubuntu/Debian: sudo apt install jq curl git"
        echo "macOS: brew install jq curl git"
        echo "CentOS/RHEL: sudo yum install jq curl git"
        return 1
    fi
    
    # Controlla installazione marvin
    echo ""
    echo_info "Installazione Marvin:"
    if command -v marvin >/dev/null 2>&1; then
        echo_success "marvin command disponibile ($(which marvin))"
        local marvin_path=$(which marvin)
        if [ -x "$marvin_path" ]; then
            echo_success "marvin è eseguibile"
        else
            echo_error "marvin non è eseguibile"
            echo "Esegui: chmod +x $marvin_path"
        fi
    else
        echo_error "marvin command non trovato"
        echo "Reinstalla con: bash setup.sh"
        return 1
    fi
    
    echo ""
    echo_success "Configurazione verificata con successo!"
}

# Funzione: Analizza la salute del progetto - MIGLIORATA
analyze_project() {
    if [ ! -d "$PROJECT_MEMORY" ]; then
        echo_error "Non sei in un progetto Marvin"
        return 1
    fi
    
    echo_info "Analisi salute progetto Marvin v8.2"
    echo "======================================"
    
    # Controlla file memoria
    local required_files=("idea.md" "vibe.md" "state.md" "decisions.md")
    local missing_files=()
    local present_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$PROJECT_MEMORY/$file" ]; then
            missing_files+=("$file")
        else
            present_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo_success "Tutti i file di memoria principali presenti (${#present_files[@]}/4)"
    else
        echo_warning "File mancanti: ${missing_files[*]}"
        echo "Usa 'marvin chat' per ricrearli automaticamente"
    fi
    
    # Analizza dimensioni file con soglie sensate
    echo ""
    echo_info "Dimensioni file memoria:"
    for file in "$PROJECT_MEMORY"/*.md; do
        if [ -f "$file" ]; then
            local lines=$(wc -l < "$file")
            local chars=$(wc -c < "$file")
            local basename=$(basename "$file")
            
            if [ "$lines" -gt 100 ]; then
                echo_warning "$basename: $lines righe, $chars caratteri (molto grande)"
            elif [ "$lines" -gt 50 ]; then
                echo_info "$basename: $lines righe, $chars caratteri (normale)"
            else
                echo_success "$basename: $lines righe, $chars caratteri (compatto)"
            fi
        fi
    done
    
    # Controlla log sessione con pulizia automatica
    if [ -f "$PROJECT_MEMORY/session.log" ]; then
        local log_lines=$(wc -l < "$PROJECT_MEMORY/session.log")
        if [ "$log_lines" -gt 200 ]; then
            echo_warning "session.log: $log_lines righe (verrà pulito automaticamente)"
        else
            echo_success "session.log: $log_lines righe"
        fi
    fi
    
    # Controlla stack consistency MIGLIORATA
    echo ""
    echo_info "Controllo coerenza stack:"
    if [ -f "$PROJECT_MEMORY/state.md" ]; then
        if grep -q "Non ancora definito" "$PROJECT_MEMORY/state.md" 2>/dev/null; then
            echo_warning "Stack non ancora definito in state.md"
        else
            # Estrai info stack
            local frontend=$(grep -A1 "Frontend" "$PROJECT_MEMORY/state.md" | tail -1 | sed 's/.*: //' | sed 's/ ✅//' | sed 's/ ❌//')
            local backend=$(grep -A1 "Backend" "$PROJECT_MEMORY/state.md" | tail -1 | sed 's/.*: //' | sed 's/ ✅//' | sed 's/ ❌//')
            
            echo_success "Stack definito:"
            echo "   Frontend: $frontend"
            echo "   Backend: $backend"
        fi
    fi
    
    # Verifica Git
    echo ""
    echo_info "Status Git:"
    if [ -d ".git" ]; then
        local branch=$(git branch --show-current 2>/dev/null || echo "non-inizializzato")
        echo_success "Repository Git attivo (branch: $branch)"
        
        if git remote get-url origin >/dev/null 2>&1; then
            echo_success "Remote configurato: $(git remote get-url origin)"
        else
            echo_warning "Nessun remote configurato"
            echo "Usa: marvin git <URL_REPOSITORY>"
        fi
        
        # Controlla modifiche non committate
        if ! git diff --quiet 2>/dev/null; then
            local modified_count=$(git diff --name-only | wc -l)
            echo_info "File modificati non committati: $modified_count"
        fi
    else
        echo_warning "Repository Git non inizializzato"
        echo "Verrà inizializzato automaticamente al primo commit"
    fi
}

# Funzione: Test connessione AI
test_ai_connection() {
    local provider="${1:-$(jq -r '.default_ai' "$MARVIN_HOME/config.json" 2>/dev/null)}"
    
    if [ -z "$provider" ] || [ "$provider" = "null" ]; then
        echo_error "Provider AI non specificato"
        return 1
    fi
    
    echo_info "Test connessione AI: $provider"
    
    local config_file="$MARVIN_HOME/config.json"
    
    # Simula le funzioni di chiamata API (versioni semplificate per test)
    case "$provider" in
        "claude")
            local api_key=$(jq -r '.ai_providers.claude.api_key' "$config_file")
            if [ "$api_key" = "" ] || [ "$api_key" = "null" ]; then
                echo_error "API key Claude non configurata"
                return 1
            fi
            
            local response=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
                -H "Content-Type: application/json" \
                -H "x-api-key: $api_key" \
                -H "anthropic-version: 2023-06-01" \
                -d '{
                    "model": "claude-3-haiku-20240307",
                    "max_tokens": 10,
                    "messages": [{"role": "user", "content": "Test"}]
                }')
            
            local ai_response=$(echo "$response" | jq -r '.content[0].text // .error.message // "errore parsing"' 2>/dev/null)
            ;;
        "ollama")
            if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                echo_error "Ollama non raggiungibile su localhost:11434"
                return 1
            fi
            
            local response=$(curl -s -X POST "http://localhost:11434/api/generate" \
                -H "Content-Type: application/json" \
                -d '{"model": "llama2", "prompt": "Say OK", "stream": false}')
            
            local ai_response=$(echo "$response" | jq -r '.response // .error // "errore parsing"' 2>/dev/null)
            ;;
        *)
            echo_warning "Test non implementato per provider: $provider"
            return 0
            ;;
    esac
    
    if [[ "$ai_response" =~ [Oo][Kk] ]] || [[ "$ai_response" =~ [Tt]est ]]; then
        echo_success "Connessione AI funzionante: $ai_response"
    else
        echo_error "Risposta AI inaspettata: $ai_response"
        return 1
    fi
}

# Funzione: Genera report progetto completo
generate_report() {
    if [ ! -d "$PROJECT_MEMORY" ]; then
        echo_error "Non sei in un progetto Marvin"
        return 1
    fi
    
    local report_file="marvin_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Report Progetto Marvin
Generato il: $(date)

## Idea e Obiettivi
\`\`\`markdown
$(cat "$PROJECT_MEMORY/idea.md" 2>/dev/null || echo "File non trovato")
\`\`\`

## Stato Attuale
\`\`\`markdown  
$(cat "$PROJECT_MEMORY/state.md" 2>/dev/null || echo "File non trovato")
\`\`\`

## Decisioni Prese
\`\`\`markdown
$(cat "$PROJECT_MEMORY/decisions.md" 2>/dev/null || echo "File non trovato")
\`\`\`

## Struttura File
\`\`\`
$(find . -type f -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" | grep -v node_modules | grep -v .git | grep -v .marvin_memory | head -20)
\`\`\`

## Attività Recente
\`\`\`
$(tail -n 10 "$PROJECT_MEMORY/session.log" 2>/dev/null || echo "Nessuna attività registrata")
\`\`\`

## Statistiche
- File memoria: $(ls -1 "$PROJECT_MEMORY"/*.md 2>/dev/null | wc -l)
- Dimensione memoria: $(du -sh "$PROJECT_MEMORY" 2>/dev/null | cut -f1)
- Repository Git: $([ -d ".git" ] && echo "Sì" || echo "No")
- Remote configurato: $(git remote get-url origin 2>/dev/null || echo "No")
EOF

    echo_success "Report generato: $report_file"
}

# Main script dispatcher COMPLETO
case "$1" in
    "check")
        check_config
        ;;
    "analyze")
        analyze_project
        ;;
    "test-ai")
        test_ai_connection "$2"
        ;;
    "backup")
        if [ ! -d "$PROJECT_MEMORY" ]; then
            echo_error "Non sei in un progetto Marvin"
            exit 1
        fi
        local backup_name="marvin_backup_$(date +%Y%m%d_%H%M%S)"
        cp -r "$PROJECT_MEMORY" "${backup_name}"
        echo_success "Backup creato: ${backup_name}"
        ;;
    "clean")
        if [ ! -f "$PROJECT_MEMORY/session.log" ]; then
            echo_error "File session.log non trovato"
            exit 1
        fi
        
        local lines=$(wc -l < "$PROJECT_MEMORY/session.log")
        if [ "$lines" -gt 50 ]; then
            tail -n 30 "$PROJECT_MEMORY/session.log" > "$PROJECT_MEMORY/session.log.tmp"
            mv "$PROJECT_MEMORY/session.log.tmp" "$PROJECT_MEMORY/session.log"
            echo_success "Log pulito: mantenute ultime 30 righe di $lines"
        else
            echo_info "Log già di dimensioni ottimali: $lines righe"
        fi
        ;;
    "fix-config")
        if [ ! -f "$MARVIN_HOME/config.json" ]; then
            echo_info "Creando config.json da template..."
            # Template inline di emergenza
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
    "groq": {
      "name": "Groq Llama",
      "api_url": "https://api.groq.com/openai/v1/chat/completions",
      "api_key": "",
      "model": "llama-3.1-70b-versatile",
      "max_tokens": 4096
    },
    "ollama": {
      "name": "Ollama Local",
      "api_url": "http://localhost:11434/api/generate",
      "api_key": "none",
      "model": "codellama:13b",
      "max_tokens": 4096
    }
  },
  "system_prompt": "Sei Marvin, assistente AI per sviluppo software. Rispondi in italiano. Usa MARVIN_ACTION per modificare file."
}
EOF
            echo_success "config.json creato con tutti i provider"
            echo_warning "Configura le API key in $MARVIN_HOME/config.json"
        else
            echo_info "File config.json già esistente"
        fi
        ;;
    "report")
        generate_report
        ;;
    *)
        echo "Utility Marvin v8.2 - Gestione e manutenzione"
        echo ""
        echo "Comandi disponibili:"
        echo "  check                 Verifica configurazione sistema completa"
        echo "  analyze               Analizza salute progetto corrente"
        echo "  test-ai [provider]    Testa connessione AI"
        echo "  backup                Backup memoria progetto corrente"
        echo "  clean                 Pulisce log di sessione"
        echo "  fix-config            Ricrea file config.json"
        echo "  report                Genera report completo progetto"
        echo ""
        echo "Esempi:"
        echo "  bash utilities.sh check"
        echo "  bash utilities.sh analyze"
        echo "  bash utilities.sh test-ai claude"
        echo "  bash utilities.sh backup"
        echo "  bash utilities.sh clean"
        echo "  bash utilities.sh fix-config"
        echo "  bash utilities.sh report"
        echo ""
        echo "Diagnostic completa:"
        echo "  bash utilities.sh check && bash utilities.sh analyze"
        ;;
esac