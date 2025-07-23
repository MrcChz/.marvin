#!/bin/bash

# Marvin AI Client Module - FINAL FIX v3.3
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

# Parser CORRETTO che gestisce BLOCCHI, non righe singole
parse_ai_commands() {
    local ai_response="$1"
    local commands_file="$AI_TEMP_DIR/commands.txt"
    
    > "$commands_file"
    echo "🤖 Marvin: \"Parser CORRETTO per blocchi...\""
    
    # Salva la risposta per debug
    echo "$ai_response" > "$AI_TEMP_DIR/ai_response.txt"
    
    # Parser SED che estrae i blocchi completi
    local block_count=0
    
    # Usa sed per estrarre blocchi tra MARVIN_ACTION e MARVIN_END
    echo "$ai_response" | sed -n '/MARVIN_ACTION:/,/MARVIN_END/p' | \
    while IFS= read -r line; do
        if [[ "$line" =~ ^MARVIN_ACTION: ]]; then
            # Inizio nuovo blocco
            action_line="$line"
            content=""
            
            # Leggi tutte le righe fino a MARVIN_END
            while IFS= read -r content_line; do
                if [[ "$content_line" =~ ^MARVIN_END ]]; then
                    # Fine blocco - salva
                    if [[ "$action_line" =~ MARVIN_ACTION:(CREATE|UPDATE|RUN):(.+) ]]; then
                        action_type="${BASH_REMATCH[1]}"
                        file_path="${BASH_REMATCH[2]}"
                        
                        # Salva nel file comandi con separatore sicuro
                        echo "${action_type}|||${file_path}|||${content}" >> "$commands_file"
                        ((block_count++))
                    fi
                    break
                else
                    # Aggiungi riga al contenuto
                    if [ -z "$content" ]; then
                        content="$content_line"
                    else
                        content="$content"$'\n'"$content_line"
                    fi
                fi
            done
        fi
    done
    
    # Se sed non funziona, usa parser grep + awk semplificato
    if [ ! -s "$commands_file" ]; then
        echo "🔧 Fallback parser..."
        
        # Estrai ogni blocco manualmente
        grep -n "MARVIN_ACTION:\|MARVIN_END" "$AI_TEMP_DIR/ai_response.txt" > "$AI_TEMP_DIR/markers.txt"
        
        # Processa i marker per estrarre blocchi
        while read -r marker; do
            local line_num=$(echo "$marker" | cut -d: -f1)
            local content=$(echo "$marker" | cut -d: -f2-)
            
            if [[ "$content" =~ MARVIN_ACTION:(CREATE|UPDATE|RUN):(.+) ]]; then
                local action_type="${BASH_REMATCH[1]}"
                local file_path="${BASH_REMATCH[2]}"
                local start_line=$((line_num + 1))
                
                # Trova la riga di fine
                local end_line=$(grep -n "MARVIN_END" "$AI_TEMP_DIR/ai_response.txt" | \
                               awk -F: -v start="$line_num" '$1 > start {print $1; exit}')
                
                if [ ! -z "$end_line" ]; then
                    local block_content=$(sed -n "${start_line},$((end_line-1))p" "$AI_TEMP_DIR/ai_response.txt")
                    echo "${action_type}|||${file_path}|||${block_content}" >> "$commands_file"
                    ((block_count++))
                fi
            fi
        done < "$AI_TEMP_DIR/markers.txt"
        
        rm -f "$AI_TEMP_DIR/markers.txt"
    fi
    
    if [ -s "$commands_file" ]; then
        local cmd_count=$(wc -l < "$commands_file")
        echo "🔍 Marvin ha trovato $cmd_count blocchi (non 83 righe stupide!)"
        return 0
    else
        echo "⚠️ Nessun blocco MARVIN_ACTION trovato"
        echo "🔧 Debug: pattern nella risposta:"
        grep -c "MARVIN_ACTION" "$AI_TEMP_DIR/ai_response.txt" || echo "0"
        return 1
    fi
}

# Esecuzione invariata - funziona già correttamente
execute_ai_commands() {
    local commands_file="$AI_TEMP_DIR/commands.txt"
    
    if [ ! -f "$commands_file" ] || [ ! -s "$commands_file" ]; then
        echo "⚠️ Nessun comando da eseguire"
        return 1
    fi
    
    echo "🚀 Marvin: \"Eseguendo blocchi REALI...\""
    
    local executed_count=0
    while IFS='|||' read -r action_type file_path content; do
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
                
                if [ -z "$content" ]; then
                    echo "⚠️ Contenuto vuoto per $file_path"
                    continue
                fi
                
                echo "$content" > "$file_path"
                local lines=$(echo "$content" | wc -l)
                echo "📝 Marvin ha scritto: $file_path ($lines righe)"
                
                if [ -s "$file_path" ]; then
                    echo "✅ File $file_path creato con successo"
                else
                    echo "❌ ERRORE: File $file_path vuoto!"
                fi
                
                executed_count=$((executed_count + 1))
                ;;
                
            "RUN")
                echo "🔧 Marvin esegue: $file_path"
                if echo "$file_path" | grep -E "^(npm|yarn|git|mkdir|touch|echo)" > /dev/null; then
                    eval "$file_path"
                    executed_count=$((executed_count + 1))
                else
                    echo "⚠️ Comando non sicuro ignorato"
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

echo "🤖 Marvin AI Module v3.3 FINAL: \"Parser che capisce i blocchi, finalmente!\""
