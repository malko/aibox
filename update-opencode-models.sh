#!/bin/bash
#
# Update opencode.json config with models from LM Studio server.
#
# This script fetches model information from the LM Studio API and updates
# the opencode configuration file with the correct context limits, reasoning
# capabilities, and other model properties.
#
# Usage: ./update-opencode-models.sh
#

set -e

# Configuration
LM_STUDIO_URL="http://desk.home:1234"
CONFIG_PATH="${HOME}/.config/opencode/opencode.json"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a model is a thinking model
is_thinking_model() {
    local model_id="$1"
    local model_id_lower=$(echo "$model_id" | tr '[:upper:]' '[:lower:]')
    
    if echo "$model_id_lower" | grep -qE "(thinking|reasoning|r1|deepseek-r1|gpt-oss)"; then
        return 0
    fi
    return 1
}

# Function to fetch models from LM Studio
fetch_lms_models() {
    local url="${LM_STUDIO_URL}/api/v0/models"
    local response_file="$TEMP_DIR/lms_response.json"
    
    if ! curl -s --max-time 10 "$url" > "$response_file" 2>&1; then
        echo -e "${RED}❌ Error connecting to LM Studio${NC}" >&2
        echo -e "   Make sure LM Studio is running at ${LM_STUDIO_URL}" >&2
        exit 1
    fi
    
    # Check if response is valid JSON
    if ! jq -e . "$response_file" >/dev/null 2>&1; then
        echo -e "${RED}❌ Error parsing LM Studio response${NC}" >&2
        cat "$response_file" >&2
        exit 1
    fi
    
    # Save models array to temp file
    jq -r '.data // [] | .[] | @base64' "$response_file" > "$TEMP_DIR/models_base64.txt"
    
    # Also save full response for later
    cp "$response_file" "$TEMP_DIR/models.json"
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
        
        # Add reasoning capability
        if is_thinking_model "$model_id"; then
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
    echo -e "${BLUE}🔍 Fetching models from LM Studio...${NC}"
    
    fetch_lms_models
    
    local model_count=$(wc -l < "$TEMP_DIR/models_base64.txt" | tr -d ' ')
    
    if [[ "$model_count" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No models found in LM Studio${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}📦 Found $model_count models:${NC}"
    
    # Display models
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
    
    # Copy config to temp for processing
    cp "$CONFIG_PATH" "$TEMP_DIR/config.json"
    
    echo "📝 Building models configuration..."
    
    # Build new models JSON
    build_models_json "$TEMP_DIR/models_base64.txt" "$TEMP_DIR/new_models.json"
    
    echo "🔄 Updating config..."
    
    # Ensure provider exists
    if ! jq -e '.provider' "$TEMP_DIR/config.json" >/dev/null 2>&1; then
        jq '. + {"provider": {}}' "$TEMP_DIR/config.json" > "$TEMP_DIR/config_new.json"
        mv "$TEMP_DIR/config_new.json" "$TEMP_DIR/config.json"
    fi
    
    # Ensure lms provider exists with proper structure
    if ! jq -e '.provider.lms' "$TEMP_DIR/config.json" >/dev/null 2>&1; then
        jq ".provider += {\"lms\": {\"npm\": \"@ai-sdk/openai-compatible\", \"name\": \"LM studio (local)\", \"options\": {\"baseUrl\": \"${LM_STUDIO_URL}/v1\"}, \"models\": {}}}" "$TEMP_DIR/config.json" > "$TEMP_DIR/config_new.json"
        mv "$TEMP_DIR/config_new.json" "$TEMP_DIR/config.json"
    fi
    
    # Replace models section with new data
    local new_models=$(cat "$TEMP_DIR/new_models.json")
    jq ".provider.lms.models = $new_models" "$TEMP_DIR/config.json" > "$TEMP_DIR/config_new.json"
    mv "$TEMP_DIR/config_new.json" "$TEMP_DIR/config.json"
    
    # Count models
    local final_count=$(jq '.provider.lms.models | keys | length' "$TEMP_DIR/config.json")
    echo -e "\n${GREEN}✅ Configured $final_count models from LM Studio${NC}"
    
    # Save config with backup
    local backup_path="${CONFIG_PATH}.backup"
    cp "$CONFIG_PATH" "$backup_path"
    cp "$TEMP_DIR/config.json" "$CONFIG_PATH"
    
    echo -e "${GREEN}✅ Config updated: $CONFIG_PATH${NC}"
    echo -e "   Backup saved: $backup_path"
    echo -e "\n${GREEN}🎉 Done!${NC}"
}

# Run main function
main
