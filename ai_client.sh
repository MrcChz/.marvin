#!/bin/bash

# Marvin AI Client Module - FINAL FIX v3.4
# "Un parser che FINALMENTE capisce i blocchi invece di fare un disastro"

AI_TEMP_DIR="$MARVIN_HOME/temp"
mkdir -p "$AI_TEMP_DIR"

# [Funzioni API - rimangono identiche]
call_claude_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.claude.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.claude.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ model: $model, max_tokens: 4096, messages: [{ role: "user", content: $message }] }')
    curl -s -X POST "https://api.anthropic.com/v1/messages" -H "Content-Type: application/json" -H "x-api-key: $api_key" -H "anthropic-version: 2023-06-01" -d "$payload" 2>/dev/null
}

call_openai_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.openai.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.openai.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ model: $model, max_tokens: 4096, messages: [{ role: "user", content: $message }] }')
    curl -s -X POST "https://api.openai.com/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d "$payload" 2>/dev/null  
}

call_groq_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.groq.api_key' "$config_file")
    local model=$(jq -r '.ai_providers.groq.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ model: $model, max_tokens: 4096, messages: [{ role: "user", content: $message }] }')
    curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d "$payload" 2>/dev/null
}

call_azure_api() {
    local message="$1"; local config_file="$2"
    local api_key=$(jq -r '.ai_providers.azure.api_key' "$config_file")
    local api_url=$(jq -r '.ai_providers.azure.api_url' "$config_file")
    local payload=$(jq -n --arg message "$message" '{ max_tokens: 4096, messages: [{ role: "user", content: $message }] }')
    curl -s -X POST "$api_url" -H "Content-Type: application/json" -H "api-key: $api_key" -d "$payload" 2>/dev/null
}

call_ollama_api() {
    local message="$1"; local config_file="$2"
    local model=$(jq -r '.ai_providers.ollama.model' "$config_file")
    local payload=$(jq -n --arg model "$model" --arg message "$message" '{ model: $model, prompt: $message, stream: false }')
    curl -s -X POST "http://localhost:11434/api/generate" -H "Content-Type: application/json" -d "$payload" 2>/dev/null
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

# <<< FIX: Funzione parser completamente riscritta per essere robusta
parse_ai_commands() {
    local ai_response="$1"
    local commands_file="$AI_TEMP_DIR/commands.txt"
    
    > "$commands_file" # Svuota il file dei comandi
    echo "🤖 Marvin: \"Parser a stato singolo attivato...\""
    
    # Salva la risposta completa per debug
    echo "$ai_response" > "$AI_TEMP_DIR/ai_response.txt"

    # Estrae solo i blocchi MARVIN_ACTION
    local blocks=$(echo "$ai_response" | sed -n '/MARVIN_ACTION:/,/MARVIN_END/p')

    local in_block=false
    local action_type=""
    local file_path=""
    local content=""
    local block_count=0

    # Legge i blocchi riga per riga con un singolo ciclo
    while IFS= read -r line; do
        if [[ "$line" =~ ^MARVIN_ACTION:(CREATE|UPDATE|RUN):(.+) ]]; then
            # Se eravamo già in un blocco, è un errore, ma lo ignoriamo e partiamo da capo
            action_type="${BASH_REMATCH[1]}"
            file_path="${BASH_REMATCH[2]}"
            content="" # Resetta il contenuto per il nuovo blocco
            in_block=true
        elif [[ "$line" =~ ^MARVIN_END ]]; then
            if [[ "$in_block" == "true" ]]; then
                # Fine del blocco, salviamo il comando
                local encoded_content=$(echo -n "$content" | base64 -w 0)
                echo "${action_type}|||${file_path}|||${encoded_content}" >> "$commands_file"
                ((block_count++))
                in_block=false # Usciamo dallo stato "dentro un blocco"
            fi
        elif [[ "$in_block" == "true" ]]; then
            # Siamo dentro un blocco, accumuliamo il contenuto
            if [ -z "$content" ]; then
                content="$line"
            else
                content="$content"$'\n'"$line"
            fi
        fi
    done <<< "$blocks" # Alimenta il ciclo con i blocchi estratti

    if [ "$block_count" -gt 0 ]; then
        echo "🔍 Marvin ha trovato e parsato correttamente $block_count blocco/i."
        return 0
    else
        echo "⚠️ Nessun blocco MARVIN_ACTION valido trovato."
        return 1
    fi
}

execute_ai_commands() {
    local commands_file="$AI_TEMP_DIR/commands.txt"
    
    if [ ! -f "$commands_file" ] || [ ! -s "$commands_file" ]; then
        echo "⚠️ Nessun comando da eseguire"
        return 1
    fi
    
    echo "🚀 Marvin: \"Eseguendo blocchi REALI...\""
    
    local executed_count=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        action_type="${line%%|||*}"
        rest="${line#*|||}"
        file_path="${rest%%|||*}"
        encoded_content="${rest#*|||}" # Questo è il contenuto codificato

        # <<< FIX: Aggiunta la decodifica Base64 prima di qualsiasi azione
        content=$(echo "$encoded_content" | base64 -d)

        echo "🔧 Eseguendo: $action_type su $file_path"
        
        case "$action_type" in
            "CREATE"|"UPDATE")
                if [ -z "$file_path" ] || [ "$file_path" = " " ]; then
                    echo "❌ File path vuoto, saltando..."
                    continue
                fi
                
                local dir_path=$(dirname "$file_path")
                if [ "$dir_path" != "." ] && [ ! -d "$dir_path" ]; then
                    mkdir -p "$dir_path"
                    echo "📁 Creata directory: $dir_path"
                fi
                
                # Ora usiamo il contenuto decodificato
                if [ -z "$content" ]; then
                    echo "⚠️ Contenuto vuoto per $file_path (dopo decodifica), saltando"
                    continue
                fi
                
                echo -n "$content" > "$file_path" # Usiamo echo -n per evitare una newline extra
                local lines=$(echo "$content" | wc -l)
                echo "📝 Marvin ha scritto: $file_path ($lines righe)"
                
                if [ -s "$file_path" ]; then
                    echo "✅ File $file_path creato/aggiornato con successo"
                else
                    echo "❌ ERRORE: File $file_path è vuoto dopo la scrittura!"
                fi
                
                executed_count=$((executed_count + 1))
                ;;
                
            "RUN")
                # Il contenuto di RUN non è codificato, usiamo direttamente file_path
                echo "🔧 Marvin esegue: $file_path"
                if echo "$file_path" | grep -Eq "^(npm|yarn|git|mkdir|touch|echo|npx|cd)"; then
                    eval "$file_path"
                    executed_count=$((executed_count + 1))
                else
                    echo "⚠️ Comando non sicuro ignorato: $file_path"
                fi
                ;;
        esac
    done < "$commands_file"
    
    echo "✅ Marvin ha eseguito $executed_count azioni REALI"
    
    rm -f "$commands_file" "$AI_TEMP_DIR/ai_response.txt"
    return $executed_count
}

# Tracking functions rimangono invariate
track_user_request() {
    local user_request="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local session_log="$AI_TEMP_DIR/session.log"
    echo "[$timestamp] USER: $user_request" >> "$session_log"
    echo "🕒 Richiesta tracciata: $(echo "$user_request" | cut -c1-50)..."
}

track_ai_actions() {
    local ai_response="$1"
    local executed_count="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local session_log="$AI_TEMP_DIR/session.log"
    echo "[$timestamp] AI_ACTIONS: Eseguiti $executed_count comandi" >> "$session_log"
    
    if [ -d ".amazonq/vibes" ]; then
        echo "" >> ".amazonq/vibes/decisions.md"
        echo "- **$timestamp**: Marvin ha eseguito $executed_count modifiche automatiche" >> ".amazonq/vibes/decisions.md"
    fi
}

auto_update_context() {
    local ai_response="$1"
    local project_dir="$2"
    local user_request="$3"
    local context_dir="$project_dir/.amazonq/vibes"
    
    if [ -d "$context_dir" ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M')
        echo "" >> "$context_dir/state.md"
        echo "## Marvin Auto-update $timestamp" >> "$context_dir/state.md"
        echo "**Richiesta**: $user_request" >> "$context_dir/state.md"
        
        local action_count=$(echo "$ai_response" | grep -c "MARVIN_ACTION:")
        echo "**Azioni eseguite**: $action_count modifiche automatiche" >> "$context_dir/state.md"
        
        local modified_files=$(echo "$ai_response" | grep "MARVIN_ACTION:" | sed 's/.*:\(.*\)/\1/' | head -5)
        if [ ! -z "$modified_files" ]; then
            echo "**File modificati**:" >> "$context_dir/state.md"
            echo "$modified_files" | while read file; do
                echo "- $file" >> "$context_dir/state.md"
            done
        fi
        
        echo "# Marvin: \"Modifiche tracciate automaticamente.\"" >> "$context_dir/state.md"
        echo "🔄 Contesto aggiornato automaticamente"
    fi
}

check_api_config() {
    local provider="$1"; local config_file="$2"
    case "$provider" in
        "ollama") curl -s --max-time 2 http://localhost:11434/api/tags > /dev/null 2>&1 ;;
        *) 
            local api_key=$(jq -r ".ai_providers.$provider.api_key" "$config_file" 2>/dev/null)
            [ ! -z "$api_key" ] && [ "$api_key" != "null" ] && [ "$api_key" != "" ]
            ;;
    esac
}

echo "🤖 Marvin AI Module v3.4 FINAL: \"Parser che capisce i blocchi, finalmente!\""