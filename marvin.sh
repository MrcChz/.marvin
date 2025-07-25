#!/bin/bash

# Marvin AI Client - Sistema Unificato v8.2 FIXED
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
    
    if [ "$api_key" = "null" ] || [ -z "$api_key" ]; then
        echo '{"error": {"message": "API key Claude non configurata"}}'
        return 1
    fi
    
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
    
    if [ "$api_key" = "null" ] || [ -z "$api_key" ]; then
        echo '{"error": {"message": "API key OpenAI non configurata"}}'
        return 1
    fi
    
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
    
    if [ "$api_key" = "null" ] || [ -z "$api_key" ]; then
        echo '{"error": {"message": "API key Groq non configurata"}}'
        return 1
    fi
    
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
    
    # Test connessione Ollama
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo '{"error": {"message": "Ollama service non raggiungibile su localhost:11434"}}'
        return 1
    fi
    
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
    
    if [ "$api_key" = "null" ] || [ -z "$api_key" ] || [ "$api_url" = "null" ] || [ -z "$api_url" ]; then
        echo '{"error": {"message": "API key o URL Azure non configurati"}}'
        return 1
    fi
    
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
    
    # Verifica che il provider esista nella configurazione
    local provider_exists=$(jq -r ".ai_providers | has(\"$provider\")" "$config_file")
    if [ "$provider_exists" != "true" ]; then
        echo '{"error": {"message": "Provider AI non configurato: '$provider'"}}'
        return 1
    fi
    
    case "$provider" in
        "claude") call_claude_api "$message" "$config_file" ;;
        "openai") call_openai_api "$message" "$config_file" ;;
        "groq") call_groq_api "$message" "$config_file" ;;
        "ollama") call_ollama_api "$message" "$config_file" ;;
        "azure") call_azure_api "$message" "$config_file" ;;
        *) echo '{"error": {"message": "Provider non supportato: '$provider'"}}' ;;
    esac
}

extract_ai_response() {
    local provider="$1" api_response="$2"
    
    # Verifica se c'è un errore nella risposta
    local error_msg=$(echo "$api_response" | jq -r '.error.message // empty' 2>/dev/null)
    if [ -n "$error_msg" ]; then
        echo "❌ Errore API ($provider): $error_msg" >&2
        return 1
    fi
    
    case "$provider" in
        "claude") 
            echo "$api_response" | jq -r '.content[0].text // empty' 2>/dev/null 
            ;;
        "openai"|"groq"|"azure") 
            echo "$api_response" | jq -r '.choices[0].message.content // empty' 2>/dev/null 
            ;;
        "ollama") 
            echo "$api_response" | jq -r '.response // empty' 2>/dev/null 
            ;;
        *) 
            echo "" 
            ;;
    esac
}

# --- GESTIONE MEMORIA E ALBERATURA ---

update_project_tree() {
    local tree_file="$PROJECT_MEMORY/tree.md"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Genera l'alberatura corrente con find
    local current_tree=$(find . -type f \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        -not -path '*/dist/*' \
        -not -path '*/build/*' \
        -not -path '*/.marvin_memory/*' \
        -not -name '*.log' \
        -not -name '.DS_Store' \
        -not -name 'Thumbs.db' \
        | sort \
        | sed 's|^\./||' \
        | head -50)
    
    cat > "$tree_file" << EOF
# Alberatura Progetto

## Struttura Corrente (aggiornata: $timestamp)
\`\`\`
$current_tree
\`\`\`

## Info
- File mostrati: $(echo "$current_tree" | wc -l)
- Esclusi: node_modules, .git, dist, build, .marvin_memory, *.log
- Ultimo aggiornamento: $timestamp
EOF
}

handle_file_removal() {
    local file_path="$1"
    
    if [ ! -e "$file_path" ]; then
        echo "⚠️ File non trovato: $file_path"
        return 1
    fi
    
    echo "🗑️ REMOVE: $file_path"
    
    local timestamp=$(date '+%H:%M:%S')
    echo "[$timestamp] REMOVED: $file_path" >> "$PROJECT_MEMORY/session.log"
    
    rm -f "$file_path"
    update_project_tree
    
    return 0
}

update_state_md() {
    local new_content="$1"
    local state_file="$PROJECT_MEMORY/state.md"
    
    if [ -z "$new_content" ]; then
        echo "⚠️ SICUREZZA: Tentativo di scrivere state.md vuoto - BLOCCATO"
        return 1
    fi
    
    if [ -f "$state_file" ] && [ -s "$state_file" ]; then
        cp "$state_file" "$state_file.backup"
    fi
    
    local temp_file="$state_file.tmp"
    echo "$new_content" > "$temp_file"
    
    if [ -s "$temp_file" ]; then
        mv "$temp_file" "$state_file"
        local timestamp=$(date '+%H:%M:%S')
        echo "[$timestamp] UPDATED: state.md ($(wc -l < "$state_file") righe)" >> "$PROJECT_MEMORY/session.log"
        rm -f "$state_file.backup"
    else
        echo "❌ ERRORE: Impossibile aggiornare state.md"
        if [ -f "$state_file.backup" ]; then
            mv "$state_file.backup" "$state_file"
            echo "🔄 Ripristinato state.md da backup"
        fi
        rm -f "$temp_file"
        return 1
    fi
}

update_decisions_md() {
    local new_content="$1"
    local decisions_file="$PROJECT_MEMORY/decisions.md"
    
    if [ -z "$new_content" ] || [ ${#new_content} -lt 10 ]; then
        echo "⚠️ SICUREZZA: Contenuto decisions.md troppo breve - SALTATO"
        return 1
    fi
    
    if [ ! -f "$decisions_file" ]; then
        echo "$new_content" > "$decisions_file"
        return
    fi
    
    cp "$decisions_file" "$decisions_file.backup"
    
    local first_line=$(echo "$new_content" | head -1 | sed 's/[^a-zA-Z0-9]//g')
    if [ -n "$first_line" ] && grep -q "$first_line" "$decisions_file" 2>/dev/null; then
        echo "ℹ️ Decisione già presente, non aggiungo duplicato"
        rm -f "$decisions_file.backup"
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    cat >> "$decisions_file" << EOF

## Aggiornamento $timestamp
$new_content
EOF
    
    if [ $? -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] UPDATED: decisions.md" >> "$PROJECT_MEMORY/session.log"
        rm -f "$decisions_file.backup"
    else
        echo "❌ ERRORE: Impossibile aggiornare decisions.md"
        mv "$decisions_file.backup" "$decisions_file"
        return 1
    fi
}

cleanup_session_log() {
    local session_file="$PROJECT_MEMORY/session.log"
    
    if [ ! -f "$session_file" ]; then
        return 0
    fi
    
    local line_count=$(wc -l < "$session_file")
    
    if [ "$line_count" -gt 200 ]; then
        tail -n 100 "$session_file" > "$session_file.tmp"
        mv "$session_file.tmp" "$session_file"
        echo "[$(date '+%H:%M:%S')] LOG: Pulito automaticamente (era $line_count righe)" >> "$session_file"
    fi
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
        if [[ "$line" =~ ^MARVIN_ACTION:(CREATE|UPDATE|REMOVE|RUN):(.+)$ ]]; then
            action_type="${BASH_REMATCH[1]}"
            action_path="${BASH_REMATCH[2]}"
            content=""
            in_action=true
        elif [[ "$line" == "MARVIN_END" ]] && [[ "$in_action" == true ]]; then
            if [ "$action_type" = "RUN" ] || [ -n "$content" ] || [ "$action_type" = "REMOVE" ]; then
                local encoded_content=$(echo -n "$content" | base64 -w 0)
                local decoded_test=$(echo "$encoded_content" | base64 -d 2>/dev/null)
                
                if [ "$?" -eq 0 ] && [ "$decoded_test" = "$content" ]; then
                    echo "${action_type}|||${action_path}|||${encoded_content}" >> "$commands_file"
                    ((action_count++))
                else
                    echo "⚠️ ERRORE BASE64: Encoding fallito per $action_path - azione saltata"
                fi
            else
                echo "⚠️ CONTENUTO VUOTO: $action_type per $action_path - azione saltata"
            fi
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
    local git_changes=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        local action_type="${line%%|||*}"
        local rest="${line#*|||}"
        local action_path="${rest%%|||*}"
        local encoded_content="${rest#*|||}"
        local content=$(echo "$encoded_content" | base64 -d)
        
        case "$action_type" in
            "CREATE"|"UPDATE")
                if [ -z "$content" ] && [[ "$action_path" =~ \.(js|jsx|ts|tsx|py|php|java|cpp|c)$ ]]; then
                    echo "⚠️ SICUREZZA: Contenuto vuoto per file codice $action_path - SALTATO"
                    continue
                fi
                
                echo "📝 $action_type: $action_path"
                local dir_path=$(dirname "$action_path")
                if [ "$dir_path" != "." ] && [ ! -d "$dir_path" ]; then
                    mkdir -p "$dir_path"
                fi
                
                if [ "$action_type" = "UPDATE" ] && [ -f "$action_path" ] && [[ "$action_path" =~ \.(js|jsx|ts|tsx|json|py)$ ]]; then
                    cp "$action_path" "$action_path.marvin_backup"
                    echo "🔒 Backup creato: $action_path.marvin_backup"
                fi
                
                if [[ "$action_path" == ".marvin_memory/state.md" ]]; then
                    update_state_md "$content"
                elif [[ "$action_path" == ".marvin_memory/decisions.md" ]]; then
                    update_decisions_md "$content"
                else
                    local temp_file="$action_path.tmp"
                    echo -n "$content" > "$temp_file"
                    
                    if [ -f "$temp_file" ]; then
                        mv "$temp_file" "$action_path"
                    else
                        echo "❌ ERRORE: Impossibile scrivere $action_path"
                        continue
                    fi
                fi
                
                update_project_tree
                git_changes=true
                ((executed++))
                ;;
            "REMOVE")
                if handle_file_removal "$action_path"; then
                    git_changes=true
                    ((executed++))
                fi
                ;;
            "RUN")
                echo "⚡ RUN: $action_path"
                if [[ "$action_path" =~ ^(npm|yarn|git|mkdir|touch|echo|npx|cd|ls|cat|rm|cp|mv|chmod|pip|python|node) ]]; then
                    eval "$action_path"
                    if [[ "$action_path" =~ ^(rm|cp|mv|mkdir|npm|yarn|git) ]]; then
                        update_project_tree
                    fi
                    ((executed++))
                else
                    echo "⚠️ Comando non sicuro ignorato: $action_path"
                fi
                ;;
        esac
    done < "$commands_file"
    
    echo "✅ Marvin ha eseguito $executed azioni"
    
    cleanup_session_log
    
    if [ "$git_changes" = true ]; then
        marvin_git_commit "$executed"
    fi
}

marvin_git_commit() {
    local action_count="$1"
    
    if [ ! -d ".git" ]; then
        echo "🔧 Inizializzando repository Git..."
        git init
        git branch -M main
        
        if [ ! -f ".gitignore" ]; then
            cat > .gitignore << 'EOF'
node_modules/
dist/
.env
.env.local
*.log
.DS_Store
Thumbs.db
EOF
        fi
    fi
    
    if git diff --quiet && git diff --cached --quiet; then
        echo "ℹ️ Nessuna modifica da committare"
        return 0
    fi
    
    echo "📦 Marvin: Creando commit automatico..."
    
    git add .
    
    local commit_msg="🤖 Marvin: $action_count modifiche automatiche"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local modified_files=$(git diff --cached --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')
    if [ -n "$modified_files" ]; then
        commit_msg="$commit_msg

📝 File modificati: $modified_files
⏰ Timestamp: $timestamp
🔧 Azioni eseguite: $action_count"
    fi
    
    git commit -m "$commit_msg"
    
    if git remote get-url origin >/dev/null 2>&1; then
        echo "🚀 Marvin: Push su repository remoto..."
        git push origin main 2>/dev/null || {
            echo "⚠️ Push fallito - controlla che il remote sia configurato correttamente"
        }
    else
        echo "ℹ️ Nessun remote configurato - commit solo locale"
    fi
    
    echo "✅ Commit creato: $(git log --oneline -1)"
}

# --- GESTIONE MEMORIA PROMPT ---

build_context_prompt() {
    local user_request="$1" config_file="$2"
    local system_prompt=$(jq -r '.system_prompt' "$config_file")
    
    local idea_content=""
    local vibe_content=""
    local state_content=""
    local decisions_content=""
    local session_history=""
    local tree_content=""
    
    if [ -f "$PROJECT_MEMORY/idea.md" ]; then
        idea_content=$(cat "$PROJECT_MEMORY/idea.md")
    else
        idea_content="*File idea.md non ancora creato*"
    fi
    
    if [ -f "$PROJECT_MEMORY/vibe.md" ]; then
        vibe_content=$(cat "$PROJECT_MEMORY/vibe.md")
    else
        vibe_content="*File vibe.md non ancora creato*"
    fi
    
    if [ -f "$PROJECT_MEMORY/state.md" ]; then
        state_content=$(cat "$PROJECT_MEMORY/state.md")
    else
        state_content="*File state.md non ancora creato*"
    fi
    
    if [ -f "$PROJECT_MEMORY/decisions.md" ]; then
        decisions_content=$(cat "$PROJECT_MEMORY/decisions.md")
    else
        decisions_content="*File decisions.md non ancora creato*"
    fi
    
    if [ -f "$PROJECT_MEMORY/session.log" ]; then
        session_history=$(tail -n 10 "$PROJECT_MEMORY/session.log")
    else
        session_history="*Nessuna sessione precedente*"
    fi
    
    if [ -f "$PROJECT_MEMORY/tree.md" ]; then
        tree_content=$(head -30 "$PROJECT_MEMORY/tree.md")
    else
        tree_content="*Alberatura non ancora generata*"
    fi
    
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

--- ALBERATURA PROGETTO ---
$tree_content

--- SESSIONE RECENTE ---
$session_history

=== RICHIESTA UTENTE ===
$user_request

=== IMPORTANTE ===
Per modificare file usa SEMPRE il formato:
MARVIN_ACTION:TIPO:path/file.ext
[contenuto]
MARVIN_END

Tipi disponibili: CREATE, UPDATE, REMOVE, RUN
Per aggiornare la memoria usa i path: .marvin_memory/state.md, .marvin_memory/decisions.md, etc.
EOF
}

update_session_log() {
    local user_request="$1"
    local ai_response="$2"
    local timestamp=$(date '+%H:%M:%S')
    
    # Assicurati che la directory esista
    if [ ! -d "$PROJECT_MEMORY" ]; then
        mkdir -p "$PROJECT_MEMORY"
    fi
    
    if [ ! -f "$PROJECT_MEMORY/session.log" ]; then
        touch "$PROJECT_MEMORY/session.log"
    fi
    
    echo "[$timestamp] USER: $user_request" >> "$PROJECT_MEMORY/session.log"
    
    local ai_summary=$(echo "$ai_response" | head -n 3 | tr '\n' ' ' | cut -c1-100)
    echo "[$timestamp] MARVIN: $ai_summary..." >> "$PROJECT_MEMORY/session.log"
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
    
    mkdir "$project_name"
    cd "$project_name"
    
    mkdir "$PROJECT_MEMORY"
    
    if [ -f "$MARVIN_TEMPLATES/idea.md" ]; then
        cp "$MARVIN_TEMPLATES/idea.md" "$PROJECT_MEMORY/"
        cp "$MARVIN_TEMPLATES/vibe.md" "$PROJECT_MEMORY/"
        cp "$MARVIN_TEMPLATES/state.md" "$PROJECT_MEMORY/"
        cp "$MARVIN_TEMPLATES/decisions.md" "$PROJECT_MEMORY/"
    else
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

## Livello Automazione
**ALTO**: Marvin implementa tutto automaticamente senza chiedere conferma
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
    
    echo "[$(date '+%H:%M:%S')] Progetto '$project_name' inizializzato" > "$PROJECT_MEMORY/session.log"
    
    update_project_tree
    
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
    if [ ! -d "$PROJECT_MEMORY" ]; then
        echo "❌ Non sei in un progetto Marvin"
        echo "Crea un nuovo progetto con: marvin new <nome>"
        return 1
    fi
    
    if [ ! -f "$MARVIN_CONFIG" ]; then
        echo "❌ File di configurazione non trovato: $MARVIN_CONFIG"
        echo "💡 Esegui: bash ~/.marvin/utilities.sh fix-config"
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
                
                local full_prompt=$(build_context_prompt "$user_input" "$MARVIN_CONFIG")
                
                local api_response=$(call_ai "$provider" "$full_prompt" "$MARVIN_CONFIG")
                
                if [ $? -ne 0 ]; then
                    echo "❌ Errore nella comunicazione con l'AI"
                    echo "🔍 Risposta ricevuta:"
                    echo "$api_response" | head -3
                    echo ""
                    echo "💡 Verifica la configurazione con: bash ~/.marvin/utilities.sh check"
                    continue
                fi
                
                local ai_text=$(extract_ai_response "$provider" "$api_response")
                
                if [ $? -ne 0 ] || [ -z "$ai_text" ]; then
                    echo "❌ Errore nell'estrazione della risposta AI"
                    echo "🔍 Debug info:"
                    echo "$api_response" | jq . 2>/dev/null || echo "$api_response" | head -5
                    echo ""
                    echo "💡 Possibili cause:"
                    echo "   - API key non valida o scaduta"
                    echo "   - Quota API esaurita"
                    echo "   - Servizio AI temporaneamente non disponibile"
                    echo "   - Configurazione provider errata"
                    continue
                fi
                
                update_session_log "$user_input" "$ai_text"
                
                echo ""
                echo "🤖 Marvin:"
                echo "$ai_text"
                echo ""
                
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
        grep -E "^##|^- " "$PROJECT_MEMORY/state.md" | head -10 | sed 's/^/   /'
        echo ""
    fi
    
    if [ -d ".git" ]; then
        echo "📦 GIT:"
        echo "   Branch: $(git branch --show-current 2>/dev/null || echo 'Non inizializzato')"
        if git remote get-url origin >/dev/null 2>&1; then
            echo "   Remote: $(git remote get-url origin)"
        else
            echo "   Remote: Non configurato"
        fi
        echo "   Ultimo commit: $(git log --oneline -1 2>/dev/null || echo 'Nessun commit')"
        
        local modified_files=$(git diff --name-only 2>/dev/null)
        if [ -n "$modified_files" ]; then
            echo "   File modificati: $(echo "$modified_files" | tr '\n' ', ' | sed 's/,$//')"
        fi
        echo ""
    fi
    
    echo "🧠 MEMORIA:"
    if [ -f "$PROJECT_MEMORY/session.log" ]; then
        local log_lines=$(wc -l < "$PROJECT_MEMORY/session.log")
        echo "   Session log: $log_lines righe"
        echo "   Ultima attività:"
        tail -n 3 "$PROJECT_MEMORY/session.log" | sed 's/^/     /'
    fi
    
    echo ""
    echo "📁 FILE PRINCIPALI:"
    find . -maxdepth 2 -type f \
        -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \
        -o -name "*.json" -o -name "*.md" -o -name "*.html" -o -name "*.css" \
        | grep -v node_modules | grep -v .git | grep -v .marvin_memory \
        | head -10 | sed 's/^/   /'
}

command_git_setup() {
    local repo_url="$1"
    
    if [ -z "$repo_url" ]; then
        echo "❌ URL repository mancante"
        echo "Uso: marvin git <URL_REPOSITORY>"
        echo ""
        echo "Esempi:"
        echo "  marvin git https://github.com/user/repo.git"
        echo "  marvin git git@github.com:user/repo.git"
        return 1
    fi
    
    if [ ! -d ".git" ]; then
        echo "🔧 Inizializzando repository Git..."
        git init
        git branch -M main
    fi
    
    if git remote get-url origin >/dev/null 2>&1; then
        echo "🔄 Aggiornando remote origin esistente..."
        git remote set-url origin "$repo_url"
    else
        echo "🔗 Aggiungendo remote origin..."
        git remote add origin "$repo_url"
    fi
    
    echo "🧪 Testando connessione al repository..."
    if git ls-remote origin >/dev/null 2>&1; then
        echo "✅ Connessione al repository riuscita!"
        
        if ! git log --oneline -1 >/dev/null 2>&1; then
            echo "📦 Creando commit iniziale..."
            git add .
            git commit -m "🚀 Setup iniziale progetto Marvin

📁 Progetto: $(basename $(pwd))
⏰ Data: $(date)
🤖 Versioning automatico abilitato"
        fi
        
        echo "🚀 Push iniziale..."
        git push -u origin main
        
        echo ""
        echo "✅ Repository configurato con successo!"
        echo "🤖 Marvin ora creerà automaticamente commit e push per ogni modifica"
        
    else
        echo "❌ Impossibile connettersi al repository"
        echo "Verifica che l'URL sia corretto e che tu abbia i permessi necessari"
        return 1
    fi
}

command_debug() {
    echo "🔍 Marvin Debug Info"
    echo "==================="
    
    echo "📁 MARVIN_HOME: $MARVIN_HOME"
    echo "📄 Config file: $MARVIN_CONFIG"
    echo "📂 Templates: $MARVIN_TEMPLATES"
    echo "🗂️ Temp dir: $MARVIN_TEMP"
    echo ""
    
    if [ -f "$MARVIN_CONFIG" ]; then
        echo "⚙️ CONFIGURAZIONE:"
        local default_ai=$(jq -r '.default_ai' "$MARVIN_CONFIG" 2>/dev/null || echo "Errore lettura")
        echo "   Provider default: $default_ai"
        
        echo "   Provider configurati:"
        jq -r '.ai_providers | keys[]' "$MARVIN_CONFIG" 2>/dev/null | sed 's/^/     /' || echo "     Errore lettura provider"
        echo ""
    else
        echo "❌ File di configurazione mancante"
        echo ""
    fi
    
    if [ -d "$PROJECT_MEMORY" ]; then
        echo "🧠 MEMORIA PROGETTO:"
        echo "   Directory: $PROJECT_MEMORY"
        echo "   File presenti:"
        ls -la "$PROJECT_MEMORY" | sed 's/^/     /'
        echo ""
    else
        echo "❌ Non sei in un progetto Marvin"
        echo ""
    fi
    
    echo "🔧 DIPENDENZE:"
    for cmd in jq curl git; do
        if command -v $cmd >/dev/null 2>&1; then
            echo "   ✅ $cmd: $(which $cmd)"
        else
            echo "   ❌ $cmd: non trovato"
        fi
    done
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
    "git")
        command_git_setup "$2"
        ;;
    "debug")
        command_debug
        ;;
    ""|"help"|"-h"|"--help")
        echo "Marvin AI Assistant - Sistema Unificato v8.2 FIXED"
        echo ""
        echo "Comandi:"
        echo "  new <progetto>     Crea nuovo progetto con memoria"
        echo "  chat              Avvia sessione interattiva"
        echo "  status            Mostra stato progetto corrente"
        echo "  git <url>         Configura repository Git per versioning automatico"
        echo "  debug             Mostra informazioni di debug"
        echo ""
        echo "Setup iniziale:"
        echo "  export MARVIN_HOME=\"\$HOME/.marvin\""
        echo "  bash ~/.marvin/utilities.sh fix-config"
        echo "  # Configura le API key nel file config.json"
        echo ""
        echo "Esempio workflow:"
        echo "  marvin new my-project"
        echo "  cd my-project"
        echo "  marvin git https://github.com/user/repo.git"
        echo "  marvin chat"
        echo ""
        echo "Versioning automatico:"
        echo "  Marvin crea automaticamente commit e push per ogni modifica"
        echo "  Usa 'marvin git <URL>' per configurare il repository remoto"
        ;;
    *)
        echo "❌ Comando sconosciuto: '$1'"
        echo "Usa 'marvin help' per la lista dei comandi"
        exit 1
        ;;
esac