#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Configure LLM Providers ==="

OPENCODE_CONFIG_FILE="$HOME/.config/opencode/opencode.json"

if [[ ! -f "$OPENCODE_CONFIG_FILE" ]]; then
    mkdir -p "$HOME/.config/opencode"
    echo '{ "provider": {} }' > "$OPENCODE_CONFIG_FILE"
fi

if [[ "$1" == "ollama" ]]; then
    OLLAMA_URL="${2:-http://localhost:11434}"
    print_info "Adding Ollama provider..."
    jq_cmd="{\"ollama\": {\"url\": \"$OLLAMA_URL\", \"name\": \"Ollama (local)\", \"models\": {}}}"
    echo "$jq_cmd" | jq -s '.[0] * .[1]' "$OPENCODE_CONFIG_FILE" - > tmp.json && mv tmp.json "$OPENCODE_CONFIG_FILE"
    print_success "Ollama provider added!"
fi

if [[ "$1" == "lms" ]]; then
    LMS_URL="${2:-http://localhost:1234}"
    lms_url_full="${LMS_URL}/v1"
    print_info "Adding LM Studio provider..."
    jq_cmd="{\"lms\": {\"npm\": \"@ai-sdk/openai-compatible\", \"name\": \"LM Studio (local)\", \"options\": {\"baseUrl\": \"$lms_url_full\"}, \"models\": {}}}"
    echo "$jq_cmd" | jq -s '.[0] * .[1]' "$OPENCODE_CONFIG_FILE" - > tmp.json && mv tmp.json "$OPENCODE_CONFIG_FILE"
    print_success "LM Studio provider added!"
fi
