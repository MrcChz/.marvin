#!/bin/bash

# Marvin AI Client - Sistema Unificato v8.0
# "Un assistente che capisce il contesto e implementa automaticamente"

# --- CONFIGURAZIONE INIZIALE ---
if [ -z "$MARVIN_HOME" ]; then
    echo "❌ ERRORE: MARVIN_HOME non impostato."
    echo "Aggiungi al tuo ~/.bashrc:"
    echo 'export MARVIN_HOME="$HOME/.marvin"'
    exit 1
fi

MARVIN_TEMP="$MARVIN_HOME/temp"
MARVIN_TEMPLATES="$MARVIN_HOME/templates"
MARVIN_CONFIG="$MARVIN_HOME/config.json"
PROJECT_MEMORY=".marvin_memory"

mkdir -p "$MARVIN_TEMP" "$MARVIN_TEMPLATES"

# --- API CALLS ---
call_claude_api() {
    local message="$1" config_file="$2"
    local api_key=$(jq -r '.ai_providers.claude.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.claude.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{
        "model": $model,
        "max_tokens": 4096,
        "messages": [{"role": "user", "content": $message}]
    }')
    curl -s -X POST "https://api.anthropic.com/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload"
}

call_openai_api() {
    local message="$1" config_file="$2"
    local api_key=$(jq -r '.ai_providers.openai.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.openai.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{
        "model": $model,
        "max_tokens": 4096,
        "messages": [{"role": "user", "content": $message}]
    }')
    curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload"
}

call_groq_api() {
    local message="$1" config_file="$2"
    local api_key=$(jq -r '.ai_providers.groq.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.groq.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{
        "model": $model,
        "max_tokens": 4096,
        "messages": [{"role": "user", "content": $message}]
    }')
    curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload"
}

call_ollama_api() {
    local message="$1" config_file="$2"
    local model=$(jq -r '.ai_providers.ollama.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{
        "model": $model,
        "prompt": $message,
        "stream": false
    }')
    curl -s -X POST "http://localhost:11434/api/generate" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

call_azure_api() {
    local message="$1" config_file="$2"
    local api_key=$(jq -r '.ai_providers.azure.api_key' "$config_file")
    local api_url=$(jq -r '.ai_providers.azure.api_url' "$config_file")
    local payload=$(jq -n --arg message "$message" '{
        "max_tokens": 4096,
        "messages": [{"role": "user", "content": $message}]
    }')
    curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -H "api-key: $api_key" \
        -d "$payload"
}

call_ai() {
    local provider="$1" message="$2" config_file="$3"
    case "$provider" in
        "claude") call_claude_api "$message" "$config_file" ;;
        "openai") call_openai_api "$message" "$config_file" ;;
        "groq") call_groq_api "$message" "$config_file" ;;
        "ollama") call_ollama_api "$message" "$config_file" ;;
        "azure") call_azure_api "$message" "$config_file" ;;
        *) echo '{"error": "Provider non supportato"}' ;;
    esac
}

extract_ai_response() {
    local provider="$1" api_response="$2"
    case "$provider" in
        "claude") echo "$api_response" | jq -r '.content[0].text // empty' 2>/dev/null ;;
        "openai"|"groq"|"azure") echo "$api_response" | jq -r '.choices[0].message.content // empty' 2>/dev/null ;;
        "ollama") echo "$api_response" | jq -r '.response // empty' 2>/dev/null ;;
        *) echo "" ;;
    esac
}

# --- PARSER E ESECUTORE ---
parse_marvin_actions() {
    local ai_response="$1"
    local commands_file="$MARVIN_TEMP/actions.txt"
    > "$commands_file"
    
    echo "🔍 Marvin: Parsing azioni automatiche..."
    
    local action_count=0
    local in_action=false
    local action_type=""
    local action_path=""
    local content=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^MARVIN_ACTION:(CREATE|UPDATE|RUN):(.+)$ ]]; then
            action_type="${BASH_REMATCH[1]}"
            action_path="${BASH_REMATCH[2]}"
            content=""
            in_action=true
        elif [[ "$line" == "MARVIN_END" ]] && [[ "$in_action" == true ]]; then
            local encoded_content=$(echo -n "$content" | base64 -w 0)
            echo "${action_type}|||${action_path}|||${encoded_content}" >> "$commands_file"
            ((action_count++))
            in_action=false
        elif [[ "$in_action" == true ]]; then
            if [ -z "$content" ]; then
                content="$line"
            else
                content="$content"$'\n'"$line"
            fi
        fi
    done <<< "$ai_response"
    
    if [ "$action_count" -gt 0 ]; then
        echo "✅ Trovate $action_count azioni da eseguire"
        return 0
    else
        echo "ℹ️ Nessuna azione automatica richiesta"
        return 1
    fi
}

execute_marvin_actions() {
    local commands_file="$1"
    if [ ! -s "$commands_file" ]; then
        return 1
    fi
    
    echo "🚀 Marvin: Eseguendo azioni..."
    local executed=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        local action_type="${line%%|||*}"
        local rest="${line#*|||}"
        local action_path="${rest%%|||*}"
        local encoded_content="${rest#*|||}"
        local content=$(echo "$encoded_content" | base64 -d)
        
        case "$action_type" in
            "CREATE"|"UPDATE")
                echo "📝 $action_type: $action_path"
                local dir_path=$(dirname "$action_path")
                if [ "$dir_path" != "." ] && [ ! -d "$dir_path" ]; then
                    mkdir -p "$dir_path"
                fi
                echo -n "$content" > "$action_path"
                ((executed++))
                ;;
            "RUN")
                echo "⚡ RUN: $action_path"
                if [[ "$action_path" =~ ^(npm|yarn|git|mkdir|touch|echo|npx|cd|ls|cat) ]]; then
                    eval "$action_path"
                    ((executed++))
                else
                    echo "⚠️ Comando non sicuro ignorato: $action_path"
                fi
                ;;
        esac
    done < "$commands_file"
    
    echo "✅ Marvin ha eseguito $executed azioni"
}

# --- GESTIONE MEMORIA ---
build_context_prompt() {
    local user_request="$1" config_file="$2"
    local system_prompt=$(jq -r '.system_prompt' "$config_file")
    
    # Carica la memoria del progetto
    local idea_content=""
    local vibe_content=""
    local state_content=""
    local decisions_content=""
    local session_history=""
    
    if [ -f "$PROJECT_MEMORY/idea.md" ]; then
        idea_content=$(cat "$PROJECT_MEMORY/idea.md")
    fi
    
    if [ -f "$PROJECT_MEMORY/vibe.md" ]; then
        vibe_content=$(cat "$PROJECT_MEMORY/vibe.md")
    fi
    
    if [ -f "$PROJECT_MEMORY/state.md" ]; then
        state_content=$(cat "$PROJECT_MEMORY/state.md")
    fi
    
    if [ -f "$PROJECT_MEMORY/decisions.md" ]; then
        decisions_content=$(cat "$PROJECT_MEMORY/decisions.md")
    fi
    
    if [ -f "$PROJECT_MEMORY/session.log" ]; then
        session_history=$(tail -n 10 "$PROJECT_MEMORY/session.log")
    fi
    
    # Struttura file corrente (escludendo noise)
    local file_structure=$(find . -type f -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" | grep -v node_modules | grep -v .git | grep -v .marvin_memory | head -20)
    
    # Costruisci il prompt completo
    cat << EOF
$system_prompt

=== MEMORIA PROGETTO ===

--- IDEA E OBIETTIVI ---
$idea_content

--- STILE COLLABORAZIONE ---
$vibe_content

--- STATO TECNICO ATTUALE ---
$state_content

--- DECISIONI PRESE ---
$decisions_content

--- SESSIONE RECENTE ---
$session_history

--- STRUTTURA FILE ---
$file_structure

=== RICHIESTA UTENTE ===
$user_request
EOF
}

update_session_log() {
    local user_request="$1"
    local ai_response="$2"
    echo "[$(date '+%H:%M')] USER: $user_request" >> "$PROJECT_MEMORY/session.log"
    echo "[$(date '+%H:%M')] MARVIN: $(echo "$ai_response" | head -n 3 | tr '\n' ' ')..." >> "$PROJECT_MEMORY/session.log"
}

# --- COMANDI PRINCIPALI ---
command_new() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        echo "❌ Nome progetto mancante"
        echo "Uso: marvin new <nome-progetto>"
        return 1
    fi
    
    if [ -d "$project_name" ]; then
        echo "❌ La directory '$project_name' esiste già"
        return 1
    fi
    
    echo "🚀 Creando progetto Marvin: $project_name"
    
    # Crea la struttura del progetto
    mkdir "$project_name"
    cd "$project_name"
    
    # Inizializza la memoria
    mkdir "$PROJECT_MEMORY"
    
    # Copia i template se esistono, altrimenti crea versioni base
    if [ -f "$MARVIN_TEMPLATES/idea.md" ]; then
        cp "$MARVIN_TEMPLATES/idea.md" "$PROJECT_MEMORY/"
        cp "$MARVIN_TEMPLATES/vibe.md" "$PROJECT_MEMORY/"
        cp "$MARVIN_TEMPLATES/state.md" "$PROJECT_MEMORY/"
        cp "$MARVIN_TEMPLATES/decisions.md" "$PROJECT_MEMORY/"
    else
        # Template di emergenza inline
        cat > "$PROJECT_MEMORY/idea.md" << 'EOF'
# Nuovo Progetto

## Concetto Principale
Progetto in fase di definizione.

## Criteri di Successo
- [ ] Definire gli obiettivi
- [ ] Implementare le funzionalità core
- [ ] Testare il funzionamento

## Contesto
- **Perché ora**: Da definire
- **Time box**: Da definire
EOF

        cat > "$PROJECT_MEMORY/vibe.md" << 'EOF'
# Come Lavoriamo Insieme

## Automazione Marvin
Marvin implementa automaticamente usando il formato:
```
MARVIN_ACTION:CREATE:path/file.ext
[contenuto]
MARVIN_END
```

## Preferenze Tecniche
- **Frontend**: React + Vite + Tailwind CSS
- **Backend**: Node.js + Express  
- **Database**: JSON per prototipi, PostgreSQL per produzione

## Workflow
1. Marvin legge la richiesta
2. Analizza il contesto esistente
3. Implementa con MARVIN_ACTION
4. Aggiorna automaticamente state.md
EOF

        cat > "$PROJECT_MEMORY/state.md" << 'EOF'
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

## Prossimi Passi
1. Definire l'idea del progetto
2. Scegliere lo stack tecnologico
3. Implementare la struttura base

## Focus Attuale
Inizializzazione progetto
EOF

        cat > "$PROJECT_MEMORY/decisions.md" << 'EOF'
# Log Decisioni Chiave

## Decisioni Architetturali
*Nessuna decisione architettuale ancora presa.*

## Scelte Tecnologiche
*Stack tecnologico ancora da definire.*

## Trade-off Accettati
*Nessun trade-off ancora valutato.*

## Cose da NON Rivisitare
*Nessuna decisione ancora finalizzata.*
EOF
    fi
    
    # Inizializza il log di sessione
    echo "[$(date '+%H:%M')] Progetto '$project_name' inizializzato" > "$PROJECT_MEMORY/session.log"
    
    # Crea .gitignore base
    cat > .gitignore << 'EOF'
node_modules/
dist/
.env
.env.local
*.log
.DS_Store
Thumbs.db
EOF
    
    echo "✅ Progetto '$project_name' creato!"
    echo "📁 Memoria Marvin inizializzata in .marvin_memory/"
    echo ""
    echo "Prossimi passi:"
    echo "1. cd $project_name"
    echo "2. marvin chat"
}

command_chat() {
    # Verifica che siamo in un progetto Marvin
    if [ ! -d "$PROJECT_MEMORY" ]; then
        echo "❌ Non sei in un progetto Marvin"
        echo "Crea un nuovo progetto con: marvin new <nome>"
        return 1
    fi
    
    # Verifica configurazione
    if [ ! -f "$MARVIN_CONFIG" ]; then
        echo "❌ File di configurazione non trovato: $MARVIN_CONFIG"
        return 1
    fi
    
    local provider=$(jq -r '.default_ai' "$MARVIN_CONFIG")
    echo "🤖 Marvin Chat ($provider) - Memoria caricata"
    echo "Digita 'quit' per uscire"
    echo ""
    
    while true; do
        read -p "Tu: " user_input
        
        case "$user_input" in
            "quit"|"exit"|"q")
                echo "🤖 Marvin: \"Alla prossima sessione di vibe-coding.\""
                break
                ;;
            "")
                continue
                ;;
            *)
                echo ""
                echo "🤖 Marvin ($provider) sta elaborando..."
                
                # Costruisci il prompt con contesto
                local full_prompt=$(build_context_prompt "$user_input" "$MARVIN_CONFIG")
                
                # Chiama l'AI
                local api_response=$(call_ai "$provider" "$full_prompt" "$MARVIN_CONFIG")
                local ai_text=$(extract_ai_response "$provider" "$api_response")
                
                if [ -z "$ai_text" ]; then
                    echo "❌ Errore nella comunicazione con l'AI"
                    continue
                fi
                
                # Aggiorna il log di sessione
                update_session_log "$user_input" "$ai_text"
                
                # Mostra la risposta
                echo ""
                echo "🤖 Marvin:"
                echo "$ai_text"
                echo ""
                
                # Parsa ed esegui le azioni
                local actions_file="$MARVIN_TEMP/actions.txt"
                if parse_marvin_actions "$ai_text"; then
                    execute_marvin_actions "$actions_file"
                fi
                
                echo ""
                ;;
        esac
    done
}

command_status() {
    if [ ! -d "$PROJECT_MEMORY" ]; then
        echo "❌ Non sei in un progetto Marvin"
        return 1
    fi
    
    echo "📊 Status Progetto Marvin"
    echo "========================"
    
    if [ -f "$PROJECT_MEMORY/idea.md" ]; then
        echo "💡 IDEA:"
        head -n 5 "$PROJECT_MEMORY/idea.md" | sed 's/^/   /'
        echo ""
    fi
    
    if [ -f "$PROJECT_MEMORY/state.md" ]; then
        echo "⚙️ STATO:"
        grep -E "^##|^- " "$PROJECT_MEMORY/state.md" | sed 's/^/   /'
        echo ""
    fi
    
    if [ -f "$PROJECT_MEMORY/session.log" ]; then
        echo "📝 ULTIMA ATTIVITÀ:"
        tail -n 3 "$PROJECT_MEMORY/session.log" | sed 's/^/   /'
    fi
}

# --- MAIN DISPATCHER ---
case "$1" in
    "new")
        command_new "$2"
        ;;
    "chat")
        command_chat
        ;;
    "status")
        command_status
        ;;
    ""|"help"|"-h"|"--help")
        echo "Marvin AI Assistant - Sistema Unificato"
        echo ""
        echo "Comandi:"
        echo "  new <progetto>     Crea nuovo progetto con memoria"
        echo "  chat              Avvia sessione interattiva"
        echo "  status            Mostra stato progetto corrente"
        echo ""
        echo "Setup iniziale:"
        echo "  export MARVIN_HOME=\"\$HOME/.marvin\""
        ;;
    *)
        echo "❌ Comando sconosciuto: '$1'"
        echo "Usa 'marvin help' per la lista dei comandi"
        exit 1
        ;;
esac