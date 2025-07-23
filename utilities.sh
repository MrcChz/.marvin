# utilities.sh - Script di utility per manutenzione Marvin

#!/bin/bash

# Utility per gestione e manutenzione sistema Marvin

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

# Funzione: Backup della memoria di un progetto
backup_memory() {
    if [ ! -d "$PROJECT_MEMORY" ]; then
        echo_error "Non sei in un progetto Marvin"
        return 1
    fi
    
    local backup_name="marvin_backup_$(date +%Y%m%d_%H%M%S)"
    cp -r "$PROJECT_MEMORY" "${backup_name}"
    echo_success "Backup creato: ${backup_name}"
}

# Funzione: Ripristina memoria da backup
restore_memory() {
    local backup_dir="$1"
    if [ -z "$backup_dir" ] || [ ! -d "$backup_dir" ]; then
        echo_error "Directory backup non valida: $backup_dir"
        return 1
    fi
    
    if [ -d "$PROJECT_MEMORY" ]; then
        echo_warning "Memoria esistente trovata. Creo backup..."
        backup_memory
    fi
    
    cp -r "$backup_dir" "$PROJECT_MEMORY"
    echo_success "Memoria ripristinata da: $backup_dir"
}

# Funzione: Analizza la salute del progetto
analyze_project() {
    if [ ! -d "$PROJECT_MEMORY" ]; then
        echo_error "Non sei in un progetto Marvin"
        return 1
    fi
    
    echo_info "Analisi salute progetto Marvin"
    echo "================================="
    
    # Controlla file memoria
    local missing_files=()
    for file in idea.md vibe.md state.md decisions.md; do
        if [ ! -f "$PROJECT_MEMORY/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo_success "Tutti i file di memoria presenti"
    else
        echo_warning "File mancanti: ${missing_files[*]}"
    fi
    
    # Analizza dimensioni file
    echo ""
    echo_info "Dimensioni file memoria:"
    for file in "$PROJECT_MEMORY"/*.md; do
        if [ -f "$file" ]; then
            local lines=$(wc -l < "$file")
            local basename=$(basename "$file")
            if [ "$lines" -gt 50 ]; then
                echo_warning "$basename: $lines righe (considera di riassumere)"
            else
                echo_success "$basename: $lines righe"
            fi
        fi
    done
    
    # Controlla log sessione
    if [ -f "$PROJECT_MEMORY/session.log" ]; then
        local log_lines=$(wc -l < "$PROJECT_MEMORY/session.log")
        if [ "$log_lines" -gt 100 ]; then
            echo_warning "session.log: $log_lines righe (considera pulizia)"
        else
            echo_success "session.log: $log_lines righe"
        fi
    fi
    
    # Controlla stack consistency
    echo ""
    echo_info "Controllo coerenza stack:"
    if grep -q "Non ancora definito" "$PROJECT_MEMORY/state.md" 2>/dev/null; then
        echo_warning "Stack non ancora definito in state.md"
    else
        echo_success "Stack definito in state.md"
    fi
}

# Funzione: Pulizia log di sessione
clean_session_log() {
    if [ ! -f "$PROJECT_MEMORY/session.log" ]; then
        echo_error "File session.log non trovato"
        return 1
    fi
    
    local lines=$(wc -l < "$PROJECT_MEMORY/session.log")
    if [ "$lines" -gt 50 ]; then
        tail -n 30 "$PROJECT_MEMORY/session.log" > "$PROJECT_MEMORY/session.log.tmp"
        mv "$PROJECT_MEMORY/session.log.tmp" "$PROJECT_MEMORY/session.log"
        echo_success "Log pulito: mantenute ultime 30 righe di $lines"
    else
        echo_info "Log già di dimensioni ottimali: $lines righe"
    fi
}

# Funzione: Aggiorna template globali
update_templates() {
    if [ ! -d "$MARVIN_HOME/templates" ]; then
        echo_error "Directory template non trovata: $MARVIN_HOME/templates"
        return 1
    fi
    
    echo_info "Aggiornamento template..."
    
    # Backup template esistenti
    if [ -d "$MARVIN_HOME/templates.backup" ]; then
        rm -rf "$MARVIN_HOME/templates.backup"
    fi
    cp -r "$MARVIN_HOME/templates" "$MARVIN_HOME/templates.backup"
    
    # Ricrea template da zero (qui useresti i template più aggiornati)
    echo_warning "Funzione da implementare: aggiornamento automatico template"
    echo_info "Per ora, sostituisci manualmente i file in $MARVIN_HOME/templates/"
}

# Funzione: Verifica configurazione
check_config() {
    echo_info "Verifica configurazione Marvin"
    echo "==============================="
    
    # Controlla MARVIN_HOME
    if [ -z "$MARVIN_HOME" ]; then
        echo_error "MARVIN_HOME non impostato"
    else
        echo_success "MARVIN_HOME: $MARVIN_HOME"
    fi
    
    # Controlla file config
    if [ ! -f "$MARVIN_HOME/config.json" ]; then
        echo_error "File config.json non trovato"
        return 1
    else
        echo_success "File config.json presente"
    fi
    
    # Controlla validità JSON
    if jq empty "$MARVIN_HOME/config.json" 2>/dev/null; then
        echo_success "config.json è JSON valido"
    else
        echo_error "config.json contiene errori di sintassi"
        return 1
    fi
    
    # Controlla API key
    local default_ai=$(jq -r '.default_ai' "$MARVIN_HOME/config.json")
    echo_info "Provider di default: $default_ai"
    
    local api_key=$(jq -r ".ai_providers.$default_ai.api_key" "$MARVIN_HOME/config.json")
    if [ "$api_key" = "" ] || [ "$api_key" = "null" ]; then
        echo_warning "API key per $default_ai non configurata"
    else
        echo_success "API key per $default_ai configurata"
        
        # Test specifico per Ollama
        if [ "$default_ai" = "ollama" ]; then
            if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                echo_success "Ollama service è raggiungibile"
            else
                echo_warning "Ollama service non raggiungibile (localhost:11434)"
            fi
        fi
    fi
    
    # Controlla dipendenze
    echo ""
    echo_info "Dipendenze sistema:"
    for cmd in jq curl; do
        if command -v $cmd >/dev/null 2>&1; then
            echo_success "$cmd installato"
        else
            echo_error "$cmd non trovato"
        fi
    done
}

# Funzione: Crea report progetto
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
EOF

    echo_success "Report generato: $report_file"
}

# Main script dispatcher
case "$1" in
    "backup")
        backup_memory
        ;;
    "restore")
        restore_memory "$2"
        ;;
    "analyze")
        analyze_project
        ;;
    "clean")
        clean_session_log
        ;;
    "check")
        check_config
        ;;
    "report")
        generate_report
        ;;
    "templates")
        update_templates
        ;;
    *)
        echo "Utility Marvin - Gestione e manutenzione"
        echo ""
        echo "Comandi disponibili:"
        echo "  backup                 Backup memoria progetto corrente"
        echo "  restore <dir>          Ripristina memoria da backup"
        echo "  analyze                Analizza salute progetto"
        echo "  clean                  Pulisce log di sessione"
        echo "  check                  Verifica configurazione sistema"
        echo "  report                 Genera report completo progetto"
        echo "  templates              Aggiorna template globali"
        echo ""
        echo "Esempi:"
        echo "  bash utilities.sh backup"
        echo "  bash utilities.sh analyze"
        echo "  bash utilities.sh check"
        ;;
esac