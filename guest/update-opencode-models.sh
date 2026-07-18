#!/bin/bash
#
# Update opencode.json config with models from LLM providers.
#
# This script fetches model information from LM Studio or Ollama API and updates
# the opencode configuration file with the correct context limits, reasoning
# capabilities, and other model properties.
#
# Usage: ./update-opencode-models.sh [provider]
#   provider: lmstudio or ollama (default: lmstudio)
#

set -e

CONFIG_PATH="${HOME}/.config/opencode/opencode.json"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_BASE_URL=""
API_TOKEN=""

# Function to check if a model is a thinking model
is_thinking_model() {
    local model_id="$1"
    local model_id_lower=$(echo "$model_id" | tr '[:upper:]' '[:lower:]')

    if echo "$model_id_lower" | grep -qE "(thinking|reasoning|r1|deepseek-r1|gpt-oss)"; then
        return 0
    fi
    return 1
}

fetch_models() {
    local provider="$1"
    local config_url config_token

    config_url=$(jq -r ".provider.${provider}.options.baseURL // empty" "$CONFIG_PATH")
    config_token=$(jq -r ".provider.${provider}.options.headers.Authorization // empty" "$CONFIG_PATH")

    if [[ -z "$config_url" ]]; then
        echo -e "${RED}❌ No baseURL found for provider: $provider${NC}" >&2
        exit 1
    fi

    API_BASE_URL="${config_url%/v1}"
    # Stored header value is the full "Bearer <token>" string
    API_TOKEN="${config_token#Bearer }"

    local curl_opts=("-s" "--max-time" "10")
    if [[ -n "$API_TOKEN" && "$API_TOKEN" != "null" ]]; then
        curl_opts+=("-H" "Authorization: Bearer $API_TOKEN")
    fi

    if [[ "$provider" == "ollama" ]]; then
        fetch_models_ollama "${curl_opts[@]}"
    else
        fetch_models_lmstudio "${curl_opts[@]}"
    fi
}

# Fetch models from LM Studio REST API (/api/v0/models)
fetch_models_lmstudio() {
    local api_url="${API_BASE_URL}/api/v0/models"
    local response_file="$TEMP_DIR/lmstudio_response.json"

    if ! curl "$@" "$api_url" > "$response_file"; then
        echo -e "${RED}❌ Error connecting to lmstudio${NC}" >&2
        echo -e "   Make sure the server is running at ${API_BASE_URL}${NC}" >&2
        exit 1
    fi

    if ! jq -e . "$response_file" >/dev/null 2>&1; then
        echo -e "${RED}❌ Error parsing response from lmstudio${NC}" >&2
        cat "$response_file" >&2
        exit 1
    fi

    jq -r '.data // [] | .[] | @base64' "$response_file" > "$TEMP_DIR/models_base64.txt"
}

# Fetch models from Ollama API (/api/tags + /api/show), normalized to the
# same {id, type, max_context_length, reasoning} shape as LM Studio entries
fetch_models_ollama() {
    local api_url="${API_BASE_URL}/api/tags"
    local response_file="$TEMP_DIR/ollama_response.json"
    local show_file="$TEMP_DIR/ollama_show.json"
    local name

    if ! curl "$@" "$api_url" > "$response_file"; then
        echo -e "${RED}❌ Error connecting to ollama${NC}" >&2
        echo -e "   Make sure the server is running at ${API_BASE_URL}${NC}" >&2
        exit 1
    fi

    if ! jq -e . "$response_file" >/dev/null 2>&1; then
        echo -e "${RED}❌ Error parsing response from ollama${NC}" >&2
        cat "$response_file" >&2
        exit 1
    fi

    : > "$TEMP_DIR/models_base64.txt"

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        if ! curl "$@" -H "Content-Type: application/json" \
                -d "$(jq -cn --arg m "$name" '{model: $m}')" \
                "${API_BASE_URL}/api/show" > "$show_file" \
                || ! jq -e . "$show_file" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Could not fetch details for ${name}, skipping${NC}" >&2
            continue
        fi

        jq -c --arg id "$name" '{
            id: $id,
            type: (if (.capabilities // []) | index("vision") then "vlm" else "llm" end),
            max_context_length: ((.model_info // {}) | to_entries
                | map(select(.key | endswith(".context_length")))
                | (.[0].value // null)),
            reasoning: ((.capabilities // []) | index("thinking") != null)
        }' "$show_file" | base64 -w 0 >> "$TEMP_DIR/models_base64.txt"
        echo >> "$TEMP_DIR/models_base64.txt"
    done < <(jq -r '.models // [] | .[].name' "$response_file")
}

# Function to create config key from model ID
create_config_key() {
    local model_id="$1"
    echo "$model_id" | sed 's/\//-/g'
}

# Function to build models JSON from LMS data
build_models_json() {
    local models_file="$1"
    local output_file="$2"

    echo "{}" > "$output_file"

    while IFS= read -r model_base64; do
        [[ -z "$model_base64" ]] && continue

        local model_json=$(echo "$model_base64" | base64 -d)
        local model_id=$(echo "$model_json" | jq -r '.id // empty')
        local model_type=$(echo "$model_json" | jq -r '.type // "llm"')
        local max_context=$(echo "$model_json" | jq -r '.max_context_length // empty')
        local model_id_lower=$(echo "$model_id" | tr '[:upper:]' '[:lower:]')

        [[ -z "$model_id" ]] && continue

        local config_key=$(create_config_key "$model_id")

        # Build properties object
        local props="{\"name\": \"$model_id\""

        # Add context limit if available
        if [[ -n "$max_context" && "$max_context" != "null" ]]; then
            local max_output=32000
            props="$props, \"limit\": {\"context\": $max_context, \"output\": $max_output}"
        fi

        local model_reasoning=$(echo "$model_json" | jq -r '.reasoning // false')

        # Add reasoning capability
        if [[ "$model_reasoning" == "true" ]] || is_thinking_model "$model_id"; then
            props="$props, \"reasoning\": true"
        fi

        # Add modalities for vision models
        if [[ "$model_type" == "vlm" ]]; then
            props="$props, \"modalities\": {\"input\": [\"text\", \"image\"], \"output\": [\"text\"]}"
        fi

        # Special handling for gpt-oss
        if echo "$model_id_lower" | grep -q "gpt-oss"; then
            props="$props, \"thinkingConfig\": {\"thinkingLevel\": \"medium\"}"
        fi

        props="$props}"

        # Add to models object
        local current=$(cat "$output_file")
        echo "$current" | jq ". + {\"$config_key\": $props}" > "$output_file.tmp"
        mv "$output_file.tmp" "$output_file"

    done < "$models_file"
}

# Main function
main() {
    local provider="${1:-lmstudio}"
    if [[ "$provider" == "lms" ]]; then
        provider="lmstudio"
    fi

    if [[ "$provider" != "lmstudio" && "$provider" != "ollama" ]]; then
        echo -e "${RED}❌ Invalid provider: $provider${NC}" >&2
        echo -e "   Supported providers: lmstudio, ollama${NC}" >&2
        exit 1
    fi

    echo -e "${BLUE}🔍 Fetching models from ${provider}...${NC}"

    fetch_models "$provider"

    local model_count=$(wc -l < "$TEMP_DIR/models_base64.txt" | tr -d ' ')

    if [[ "$model_count" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No models found in ${provider}${NC}"
        exit 0
    fi

    echo -e "${GREEN}📦 Found $model_count models:${NC}"

    while IFS= read -r model_base64; do
        [[ -z "$model_base64" ]] && continue
        local model_json=$(echo "$model_base64" | base64 -d)
        local model_id=$(echo "$model_json" | jq -r '.id // "unknown"')
        local model_type=$(echo "$model_json" | jq -r '.type // "llm"')
        local context=$(echo "$model_json" | jq -r '.max_context_length // "unknown"')
        echo "   - $model_id (${model_type}, ${context} context)"
    done < "$TEMP_DIR/models_base64.txt"

    echo -e "\n${BLUE}📂 Loading config from $CONFIG_PATH...${NC}"

    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}❌ Config file not found: $CONFIG_PATH${NC}" >&2
        exit 1
    fi

    if ! jq -e . "$CONFIG_PATH" >/dev/null 2>&1; then
        echo -e "${RED}❌ Error parsing config file${NC}" >&2
        exit 1
    fi

    cp "$CONFIG_PATH" "$TEMP_DIR/config.json"

    echo "📝 Building models configuration..."

    build_models_json "$TEMP_DIR/models_base64.txt" "$TEMP_DIR/new_models.json"

    echo "🔄 Updating config..."

    if ! jq -e '.provider' "$TEMP_DIR/config.json" >/dev/null 2>&1; then
        jq '. + {"provider": {}}' "$TEMP_DIR/config.json" > "$TEMP_DIR/config_new.json"
        mv "$TEMP_DIR/config_new.json" "$TEMP_DIR/config.json"
    fi

    local provider_name="LM Studio"
    if [[ "$provider" == "ollama" ]]; then
        provider_name="Ollama"
    fi

    local base_url_for_config="${API_BASE_URL}/v1"
    if ! jq -e ".provider.$provider" "$TEMP_DIR/config.json" >/dev/null 2>&1; then
        jq ".provider += {\"$provider\": {\"npm\": \"@ai-sdk/openai-compatible\", \"name\": \"${provider_name} (local)\", \"options\": {\"baseURL\": \"${base_url_for_config}\"}, \"models\": {}}}" "$TEMP_DIR/config.json" > "$TEMP_DIR/config_new.json"
        mv "$TEMP_DIR/config_new.json" "$TEMP_DIR/config.json"
    fi

    local new_models=$(cat "$TEMP_DIR/new_models.json")
    jq ".provider.${provider}.models = $new_models" "$TEMP_DIR/config.json" > "$TEMP_DIR/config_new.json"
    mv "$TEMP_DIR/config_new.json" "$TEMP_DIR/config.json"

    local final_count=$(jq ".provider.${provider}.models | keys | length" "$TEMP_DIR/config.json")
    echo -e "\n${GREEN}✅ Configured $final_count models from ${provider_name}${NC}"

    local backup_path="${CONFIG_PATH}.backup"
    cp "$CONFIG_PATH" "$backup_path"
    cp "$TEMP_DIR/config.json" "$CONFIG_PATH"

    echo -e "${GREEN}✅ Config updated: $CONFIG_PATH${NC}"
    echo -e "   Backup saved: $backup_path"
    echo -e "\n${GREEN}🎉 Done!${NC}"
}

# Run main function
main
