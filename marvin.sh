#!/bin/bash

# Marvin AI Client - Sistema Unificato v8.1
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

# Funzione per aggiornare l'alberatura del progetto
update_project_tree() {
    local tree_file="$PROJECT_MEMORY/tree.md"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Genera l'alberatura corrente (escludendo .git, node_modules, etc.)
    local current_tree=""
    if command -v tree >/dev/null 2>&1; then
        current_tree=$(tree -I 'node_modules|.git|dist|build|*.log|.DS_Store' -a 2>/dev/null)
    else
        # Fallback con find se tree non è disponibile
        current_tree=$(find . -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' -not -name '*.log' -not -name '.DS_Store' | sort | sed 's|^\./||' | awk '{
            depth = gsub(/\//, "/", $0)
            indent = ""
            for(i=0; i<depth; i++) indent = indent "  "
            filename = $0
            sub(/.*\//, "", filename)
            if(filename != "") print indent filename
        }')
    fi
    
    # Crea o aggiorna il file tree
    if [ ! -f "$tree_file" ]; then
        cat > "$tree_file" << EOF
# Alberatura Progetto

## Struttura Corrente (aggiornata: $timestamp)
\`\`\`
$current_tree
\`\`\`

## Cronologia Modifiche
*Prima generazione dell'alberatura*
EOF
    else
        # Mantieni storico delle alberature precedenti
        local old_content=$(cat "$tree_file")
        local old_tree=$(echo "$old_content" | sed -n '/```/,/```/p' | sed '1d;$d')
        
        # Confronta se ci sono modifiche significative
        if [ "$current_tree" != "$old_tree" ]; then
            cat > "$tree_file" << EOF
# Alberatura Progetto

## Struttura Corrente (aggiornata: $timestamp)
\`\`\`
$current_tree
\`\`\`

## Cronologia Modifiche

### $timestamp
Struttura aggiornata automaticamente

$(echo "$old_content" | sed -n '/## Cronologia Modifiche/,$p' | tail -n +2 | head -20)
EOF
        fi
    fi
}

# Funzione per gestire rimozione file con tracking
handle_file_removal() {
    local file_path="$1"
    
    if [ ! -e "$file_path" ]; then
        echo "⚠️ File non trovato: $file_path"
        return 1
    fi
    
    echo "🗑️ REMOVE: $file_path"
    
    # Log della rimozione
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] REMOVED: $file_path" >> "$PROJECT_MEMORY/session.log"
    
    # Rimuovi il file
    rm -f "$file_path"
    
    # Aggiorna l'alberatura
    update_project_tree
    
    return 0
}

# Funzione per aggiornare state.md mantenendo lo storico
update_state_with_history() {
    local new_content="$1"
    local state_file="$PROJECT_MEMORY/state.md"
    
    # Se il file non esiste, crealo normalmente
    if [ ! -f "$state_file" ]; then
        echo "$new_content" > "$state_file"
        return
    fi
    
    # Backup del contenuto attuale
    local backup_content=$(cat "$state_file")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Crea il nuovo contenuto con storico
    cat > "$state_file" << EOF
$new_content

---

## Storico Modifiche

### $timestamp
$(echo "$backup_content" | grep -v "^---$" | grep -v "^## Storico Modifiche" | tail -n +1)

EOF
    
    # Se c'era già uno storico, mantienilo (limitato agli ultimi 5 aggiornamenti)
    if grep -q "## Storico Modifiche" <<< "$backup_content"; then
        local historical_content=$(echo "$backup_content" | sed -n '/^## Storico Modifiche/,$p' | tail -n +2)
        
        # Aggiungi max 4 voci precedenti (per mantenere totale di 5 con quella corrente)
        local previous_entries=$(echo "$historical_content" | awk '/^### [0-9]{4}-[0-9]{2}-[0-9]{2}/ {count++} count <= 4 {print}')
        
        if [ -n "$previous_entries" ]; then
            echo "$previous_entries" >> "$state_file"
        fi
    fi
}

# Funzione per aggiornare decisions.md mantenendo lo storico
update_decisions_with_history() {
    local new_content="$1"
    local decisions_file="$PROJECT_MEMORY/decisions.md"
    
    # Se il file non esiste, crealo normalmente
    if [ ! -f "$decisions_file" ]; then
        echo "$new_content" > "$decisions_file"
        return
    fi
    
    # Per decisions.md, aggiungiamo alla fine invece di sovrascrivere
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local existing_content=$(cat "$decisions_file")
    
    # Estrai solo le nuove decisioni (quello che non era già presente)
    local new_decisions=$(echo "$new_content" | grep -v "^# Log Decisioni Chiave" | grep -v "^$")
    
    if [ -n "$new_decisions" ]; then
        cat > "$decisions_file" << EOF
$existing_content

## Aggiornamento $timestamp
$new_decisions
EOF
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
        if [[ "$line" =~ ^MARVIN_ACTION:(CREATE|UPDATE|REMOVE|DELETE|RUN):(.+)$ ]]; then
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
    local git_changes=false
    
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
                
                # Gestione speciale per file di memoria con storico
                if [[ "$action_path" == *"/.marvin_memory/state.md" ]] || [[ "$action_path" == *".marvin_memory/state.md" ]]; then
                    update_state_with_history "$content"
                elif [[ "$action_path" == *"/.marvin_memory/decisions.md" ]] || [[ "$action_path" == *".marvin_memory/decisions.md" ]]; then
                    update_decisions_with_history "$content"
                else
                    echo -n "$content" > "$action_path"
                fi
                
                # Aggiorna alberatura dopo modifiche ai file
                update_project_tree
                git_changes=true
                ((executed++))
                ;;
            "REMOVE"|"DELETE")
                if handle_file_removal "$action_path"; then
                    git_changes=true
                    ((executed++))
                fi
                ;;
            "RUN")
                echo "⚡ RUN: $action_path"
                if [[ "$action_path" =~ ^(npm|yarn|git|mkdir|touch|echo|npx|cd|ls|cat|rm) ]]; then
                    eval "$action_path"
                    # Se è un comando rm, aggiorna l'alberatura
                    if [[ "$action_path" =~ ^rm ]]; then
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
    
    # Git commit automatico se ci sono stati cambiamenti
    if [ "$git_changes" = true ]; then
        marvin_git_commit "$executed"
    fi
}

# Funzione per commit e push automatici
marvin_git_commit() {
    local action_count="$1"
    
    # Inizializza git se non esiste
    if [ ! -d ".git" ]; then
        echo "🔧 Inizializzando repository Git..."
        git init
        git branch -M main
        
        # Crea .gitignore se non esiste
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
    
    # Controlla se ci sono modifiche da committare
    if git diff --quiet && git diff --cached --quiet; then
        echo "ℹ️ Nessuna modifica da committare"
        return 0
    fi
    
    echo "📦 Marvin: Creando commit automatico..."
    
    # Aggiungi tutti i file modificati
    git add .
    
    # Crea messaggio di commit intelligente
    local commit_msg="🤖 Marvin: $action_count modifiche automatiche"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Aggiungi dettagli sui file modificati
    local modified_files=$(git diff --cached --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')
    if [ -n "$modified_files" ]; then
        commit_msg="$commit_msg

📝 File modificati: $modified_files
⏰ Timestamp: $timestamp
🔧 Azioni eseguite: $action_count"
    fi
    
    # Commit
    git commit -m "$commit_msg"
    
    # Push se esiste un remote
    if git remote get-url origin >/dev/null 2>&1; then
        echo "🚀 Marvin: Push su repository remoto..."
        git push origin main 2>/dev/null || {
            echo "⚠️ Push fallito - controlla che il remote sia configurato correttamente"
            echo "💡 Per configurare: git remote add origin <URL_REPOSITORY>"
        }
    else
        echo "ℹ️ Nessun remote configurato - commit solo locale"
        echo "💡 Per aggiungere remote: git remote add origin <URL_REPOSITORY>"
    fi
    
    echo "✅ Commit creato: $(git log --oneline -1)"
}

# --- GESTIONE MEMORIA PROMPT ---
build_context_prompt() {
    local user_request="$1" config_file="$2"
    local system_prompt=$(jq -r '.system_prompt' "$config_file")
    
    # Carica la memoria del progetto
    local idea_content=""
    local vibe_content=""
    local state_content=""
    local decisions_content=""
    local session_history=""
    local tree_content=""
    
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
    
    if [ -f "$PROJECT_MEMORY/tree.md" ]; then
        tree_content=$(head -20 "$PROJECT_MEMORY/tree.md")
    fi
    
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

--- ALBERATURA PROGETTO ---
$tree_content

--- SESSIONE RECENTE ---
$session_history

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

        cat > "$PROJECT_MEMORY/tree.md" << 'EOF'
# Alberatura Progetto

## Struttura Corrente (inizializzazione)
```
[Progetto vuoto - alberatura verrà generata automaticamente]
```

## Cronologia Modifiche
*Inizializzazione - alberatura verrà aggiornata automaticamente*
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
    
    # Genera l'alberatura iniziale
    update_project_tree
    
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
                    echo "🔍 Debug info salvato in /tmp/marvin_debug.log"
                    echo "📋 Risposta API ricevuta:"
                    echo "$api_response" | head -5
                    echo ""
                    echo "💡 Verifica la configurazione con: bash ~/.marvin/utilities.sh check"
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
    
    # Status Git
    if [ -d ".git" ]; then
        echo "📦 GIT:"
        echo "   Branch: $(git branch --show-current 2>/dev/null || echo 'Non inizializzato')"
        if git remote get-url origin >/dev/null 2>&1; then
            echo "   Remote: $(git remote get-url origin)"
        else
            echo "   Remote: Non configurato"
        fi
        echo "   Ultimo commit: $(git log --oneline -1 2>/dev/null || echo 'Nessun commit')"
        echo ""
    fi
    
    if [ -f "$PROJECT_MEMORY/session.log" ]; then
        echo "📝 ULTIMA ATTIVITÀ:"
        tail -n 3 "$PROJECT_MEMORY/session.log" | sed 's/^/   /'
    fi
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
    
    # Inizializza git se necessario
    if [ ! -d ".git" ]; then
        echo "🔧 Inizializzando repository Git..."
        git init
        git branch -M main
    fi
    
    # Configura remote origin
    if git remote get-url origin >/dev/null 2>&1; then
        echo "🔄 Aggiornando remote origin esistente..."
        git remote set-url origin "$repo_url"
    else
        echo "🔗 Aggiungendo remote origin..."
        git remote add origin "$repo_url"
    fi
    
    # Test connessione
    echo "🧪 Testando connessione al repository..."
    if git ls-remote origin >/dev/null 2>&1; then
        echo "✅ Connessione al repository riuscita!"
        
        # Prima push se necessario
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
    ""|"help"|"-h"|"--help")
        echo "Marvin AI Assistant - Sistema Unificato"
        echo ""
        echo "Comandi:"
        echo "  new <progetto>     Crea nuovo progetto con memoria"
        echo "  chat              Avvia sessione interattiva"
        echo "  status            Mostra stato progetto corrente"
        echo "  git <url>         Configura repository Git per versioning automatico"
        echo ""
        echo "Setup iniziale:"
        echo "  export MARVIN_HOME=\"\$HOME/.marvin\""
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