#!/bin/bash

# Marvin AI Client Module - STRUCTURED WORKFLOW v7.0
# "Un assistente con un workflow professionale: prima 'new', poi 'chat'."

# --- CONFIGURAZIONE E SETUP INIZIALE ---
if [ -z "$MARVIN_HOME" ]; then
    echo "❌ ERRORE CRITICO: La variabile d'ambiente MARVIN_HOME non è impostata."
    echo "   Per risolvere, esegui questi comandi e poi riprova:"
    echo '   echo '\''export MARVIN_HOME="$HOME/.marvin"'\'' >> ~/.bashrc'
    echo '   source ~/.bashrc'
    exit 1
fi

AI_TEMP_DIR="$MARVIN_HOME/temp"
MEMORY_DIR=".marvin_memory"
mkdir -p "$AI_TEMP_DIR"

# --- LIBRERIA DI FUNZIONI (API, Parser, Esecutore, Memoria) ---

# --- FUNZIONI API ---

call_claude_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.claude.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.claude.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ "model": $model, "max_tokens": 4096, "messages": [{ "role": "user", "content": $message }] }')
    curl -s -X POST "https://api.anthropic.com/v1/messages" -H "Content-Type: application/json" -H "x-api-key: $api_key" -H "anthropic-version: 2023-06-01" -d "$payload"
}

call_openai_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.openai.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.openai.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ "model": $model, "max_tokens": 4096, "messages": [{ "role": "user", "content": $message }] }')
    curl -s -X POST "https://api.openai.com/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d "$payload"
}

call_groq_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.groq.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.groq.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ "model": $model, "max_tokens": 4096, "messages": [{ "role": "user", "content": $message }] }')
    curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d "$payload"
}

call_ollama_api() {
    local message="$1"; local config_file="$2"
    local model=$(jq -r '.ai_providers.ollama.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ "model": $model, "prompt": $message, "stream": false }')
    curl -s -X POST "http://localhost:11434/api/generate" -H "Content-Type: application/json" -d "$payload"
}

call_azure_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.azure.api_key' "$config_file")
    local api_url=$(jq -r '.ai_providers.azure.api_url' "$config_file")
    local payload=$(jq -n --arg message "$message" '{ "max_tokens": 4096, "messages": [{ "role": "user", "content": $message }] }')
    curl -s -X POST "$api_url" -H "Content-Type: application/json" -H "api-key: $api_key" -d "$payload"
}

call_ai() {
    local provider="$1"; local message="$2"; local config_file="$3"
    case "$provider" in
        "claude") call_claude_api "$message" "$config_file" ;;
        "openai") call_openai_api "$message" "$config_file" ;;
        "groq") call_groq_api "$message" "$config_file" ;;
        "azure") call_azure_api "$message" "$config_file" ;;
        "ollama") call_ollama_api "$message" "$config_file" ;;
        *) echo '{"error": "Provider sconosciuto"}' ;;
    esac
}

extract_ai_response() {
    local provider="$1"; local api_response="$2"
    case "$provider" in
        "claude") echo "$api_response" | jq -r '.content[0].text // empty' 2>/dev/null ;;
        "openai"|"groq"|"azure") echo "$api_response" | jq -r '.choices[0].message.content // empty' 2>/dev/null ;;
        "ollama") echo "$api_response" | jq -r '.response // empty' 2>/dev/null ;;
        *) echo "" ;;
    esac
}

# --- PARSER ED ESECUTORE ---

parse_ai_commands() {
    local ai_response="$1"; local commands_file="$AI_TEMP_DIR/commands.txt"; > "$commands_file"
    echo "🤖 Marvin: \"Parser a stato singolo attivato...\""
    local blocks=$(echo "$ai_response" | sed -n '/MARVIN_ACTION:/,/MARVIN_END/p')
    local in_block=false; local action_type=""; local file_path=""; local content=""; local block_count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^MARVIN_ACTION:(CREATE|UPDATE|RUN):(.+) ]]; then
            action_type="${BASH_REMATCH[1]}"; file_path="${BASH_REMATCH[2]}"; content=""; in_block=true
        elif [[ "$line" =~ ^MARVIN_END ]]; then
            if [[ "$in_block" == "true" ]]; then
                local encoded_content=$(echo -n "$content" | base64 -w 0)
                echo "${action_type}|||${file_path}|||${encoded_content}" >> "$commands_file"; ((block_count++)); in_block=false
            fi
        elif [[ "$in_block" == "true" ]]; then
            if [ -z "$content" ]; then content="$line"; else content="$content"$'\n'"$line"; fi
        fi
    done <<< "$blocks"
    if [ "$block_count" -gt 0 ]; then echo "🔍 Marvin ha trovato e parsato $block_count blocco/i."; return 0;
    else echo "⚠️ Nessun blocco MARVIN_ACTION valido trovato."; return 1; fi
}

execute_ai_commands() {
    local commands_file="$1"; if [ ! -s "$commands_file" ]; then return 1; fi
    echo "🚀 Marvin: \"Eseguendo blocchi REALI...\""; local executed_count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        action_type="${line%%|||*}"; rest="${line#*|||}"; file_path="${rest%%|||*}"; encoded_content="${rest#*|||}"
        content=$(echo "$encoded_content" | base64 -d)
        case "$action_type" in
            "CREATE"|"UPDATE")
                echo "🔧 $action_type: $file_path"; if [ -z "$file_path" ]; then continue; fi
                local dir_path=$(dirname "$file_path"); if [ ! -d "$dir_path" ] && [ "$dir_path" != "." ]; then mkdir -p "$dir_path"; fi
                echo -n "$content" > "$file_path"; ((executed_count++)) ;;
            "RUN")
                echo "🔧 RUN: $file_path"
                if echo "$file_path" | grep -Eq "^(npm|yarn|git|mkdir|touch|echo|npx|cd)"; then
                    (eval "$file_path"); ((executed_count++))
                else echo "⚠️ Comando non sicuro ignorato"; fi ;;
        esac
    done < "$commands_file"; echo "✅ Marvin ha eseguito $executed_count azioni REALI"
}

# --- GESTIONE MEMORIA ---

build_full_prompt() {
    local user_request="$1"; local config_file="$2"
    local system_prompt=$(jq -r '.system_prompt' "$config_file")
    local state_context=$(cat "$MEMORY_DIR/state.md" 2>/dev/null)
    local decisions_context=$(cat "$MEMORY_DIR/decisions.md" 2>/dev/null)
    local session_history=$(tail -n 10 "$MEMORY_DIR/session.log" 2>/dev/null)
    local file_structure=$(ls -R | grep -v 'node_modules\|dist\|.git\|.marvin_memory' 2>/dev/null)
    local full_prompt="${system_prompt}\n\n--- MEMORIA PROGETTO: STATO ---\n${state_context}\n\n--- MEMORIA PROGETTO: DECISIONI ---\n${decisions_context}\n\n--- STORICO SESSIONE ---\n${session_history}\n\n--- STRUTTURA FILE ---\n${file_structure}\n\n--- RICHIESTA UTENTE ---\n${user_request}"
    echo "$full_prompt"
}

update_session_log() {
    echo "USER: $1" >> "$MEMORY_DIR/session.log"; echo "AI: $(echo "$2" | head -n 5)" >> "$MEMORY_DIR/session.log"
}

# --- GESTORI DI COMANDI SPECIFICI (Application Logic) ---

handle_new_project() {
    local project_name="$1"
    if [ -z "$project_name" ]; then
        echo "❌ ERRORE: Nome del progetto mancante."
        echo "   Uso: marvin new <nome-progetto>"
        return 1
    fi
    if [ -d "$project_name" ]; then
        echo "❌ ERRORE: La cartella '$project_name' esiste già."
        return 1
    fi

    echo "🚀 Creando il nuovo progetto Marvin: $project_name..."
    mkdir "$project_name"
    
    # Inizializza la memoria dentro la nuova cartella
    local project_memory_dir="$project_name/$MEMORY_DIR"
    mkdir "$project_memory_dir"
    echo -e "# Stato del Progetto\n\n## Stack\nNon ancora definito.\n\n## Scopo\nNon ancora definito." > "$project_memory_dir/state.md"
    echo -e "# Log delle Decisioni\n\n*Nessuna decisione importante ancora presa.*" > "$project_memory_dir/decisions.md"
    > "$project_memory_dir/session.log"

    echo -e "\n✅ Progetto '$project_name' creato con successo!"
    echo "🧠 La memoria di Marvin è stata inizializzata al suo interno."
    echo -e "\nProssimi passi:"
    echo "1. \`cd $project_name\`"
    echo "2. \`marvin chat\`"
}

handle_chat_session() {
    # Controlla se siamo in un progetto Marvin
    if [ ! -d "$MEMORY_DIR" ]; then
        echo "❌ ERRORE: Non sei all'interno di un progetto Marvin."
        echo "   Per iniziare, crea un nuovo progetto con \`marvin new <nome-progetto>\`"
        echo "   e poi entra nella sua cartella con \`cd <nome-progetto>\`."
        return 1
    fi

    CONFIG_FILE="$MARVIN_HOME/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then echo "❌ ERRORE: File di configurazione non trovato."; return 1; fi
    local provider=$(jq -r '.default_ai' "$CONFIG_FILE")
    
    echo -e "\n==================================\n🤖 Chat con Memoria con Marvin ($provider)\n=================================="
    echo "🤖 Marvin: \"Memoria progetto caricata. Cosa costruiamo (o distruggiamo) oggi?\""

    while true; do
        read -p "Tu: " user_request
        if [[ "$user_request" == "quit" ]]; then echo "🤖 Marvin: \"A dopo.\""; break; fi
        if [[ -z "$user_request" ]]; then continue; fi

        echo "🤖 Marvin ($provider) sta elaborando..."
        local full_prompt=$(build_full_prompt "$user_request" "$CONFIG_FILE")
        local api_response=$(call_ai "$provider" "$full_prompt" "$CONFIG_FILE")
        local ai_text=$(extract_ai_response "$provider" "$api_response")

        update_session_log "$user_request" "$ai_text"
        echo -e "\n🤖 Marvin:\n$ai_text\n"

        local commands_file="$AI_TEMP_DIR/commands.txt"
        if parse_ai_commands "$ai_text"; then
            execute_ai_commands "$commands_file"
        fi
        echo -e "✅ Marvin: \"Implementazione completata.\"\n"
    done
}


# --- PUNTO DI INGRESSO DELLO SCRIPT (DISPATCHER) ---
# Legge il primo argomento e decide quale gestore di comandi chiamare.

COMMAND="$1"
ARGUMENT="$2"

case "$COMMAND" in
    "new")
        handle_new_project "$ARGUMENT"
        ;;
    "chat")
        handle_chat_session
        ;;
    ""|"-h"|"--help")
        echo "Uso: marvin <comando> [argomenti]"
        echo ""
        echo "Comandi disponibili:"
        echo "  new <nome-progetto>    Crea e inizializza un nuovo progetto Marvin."
        echo "  chat                   Avvia la sessione di chat interattiva all'interno di un progetto."
        ;;
    *)
        echo "Comando non riconosciuto: '$COMMAND'"
        echo "Esegui 'marvin --help' per la lista dei comandi."
        exit 1
        ;;
esac