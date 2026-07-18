#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Configure LLM Providers ==="

OPENCODE_CONFIG_FILE="$HOME/.config/opencode/opencode.json"

if [[ ! -f "$OPENCODE_CONFIG_FILE" ]]; then
    mkdir -p "$HOME/.config/opencode"
    echo '{"$schema": "https://opencode.ai/config.json", "provider": {}}' > "$OPENCODE_CONFIG_FILE"
fi

if [[ "$1" == "ollama" ]]; then
    OLLAMA_URL="${2:-http://localhost:11434}"
    OLLAMA_TOKEN="${3:-}"
    print_info "Adding Ollama provider..."

    TMP=$(mktemp)
    if [[ -n "$OLLAMA_TOKEN" ]]; then
        jq --arg url "$OLLAMA_URL/v1" --arg token "$OLLAMA_TOKEN" \
           '.provider.ollama = {"npm": "@ai-sdk/openai-compatible", "name": "Ollama (local)", "options": {"baseURL": $url, "headers": {"Authorization": ("Bearer " + $token)}}}' \
           "$OPENCODE_CONFIG_FILE" > "$TMP" && mv "$TMP" "$OPENCODE_CONFIG_FILE"
    else
        jq --arg url "$OLLAMA_URL/v1" \
           '.provider.ollama = {"npm": "@ai-sdk/openai-compatible", "name": "Ollama (local)", "options": {"baseURL": $url}}' \
           "$OPENCODE_CONFIG_FILE" > "$TMP" && mv "$TMP" "$OPENCODE_CONFIG_FILE"
    fi

    print_success "Ollama provider added!"
fi

if [[ "$1" == "lms" ]]; then
    LMS_URL="${2:-http://localhost:1234}"
    LMS_TOKEN="${3:-}"
    lms_url_full="${LMS_URL}/v1"
    print_info "Adding LM Studio provider..."

    TMP=$(mktemp)
    if [[ -n "$LMS_TOKEN" ]]; then
        jq --arg url "$lms_url_full" --arg token "$LMS_TOKEN" \
           '.provider.lmstudio = {"npm": "@ai-sdk/openai-compatible", "name": "LM Studio (local)", "options": {"baseURL": $url, "headers": {"Authorization": ("Bearer " + $token)}}}' \
           "$OPENCODE_CONFIG_FILE" > "$TMP" && mv "$TMP" "$OPENCODE_CONFIG_FILE"
    else
        jq --arg url "$lms_url_full" \
           '.provider.lmstudio = {"npm": "@ai-sdk/openai-compatible", "name": "LM Studio (local)", "options": {"baseURL": $url}}' \
           "$OPENCODE_CONFIG_FILE" > "$TMP" && mv "$TMP" "$OPENCODE_CONFIG_FILE"
    fi

    print_success "LM Studio provider added!"
fi

if [[ "$1" == "llamacpp" || "$1" == "llama.cpp" || "$1" == "llama-cpp" ]]; then
    LLAMACPP_URL="${2:-http://localhost:8080}"
    LLAMACPP_TOKEN="${3:-}"
    print_info "Adding llama.cpp provider..."

    TMP=$(mktemp)
    if [[ -n "$LLAMACPP_TOKEN" ]]; then
        jq --arg url "$LLAMACPP_URL/v1" --arg token "$LLAMACPP_TOKEN" \
           '.provider.llamacpp = {"npm": "@ai-sdk/openai-compatible", "name": "llama.cpp (local)", "options": {"baseURL": $url, "headers": {"Authorization": ("Bearer " + $token)}}}' \
           "$OPENCODE_CONFIG_FILE" > "$TMP" && mv "$TMP" "$OPENCODE_CONFIG_FILE"
    else
        jq --arg url "$LLAMACPP_URL/v1" \
           '.provider.llamacpp = {"npm": "@ai-sdk/openai-compatible", "name": "llama.cpp (local)", "options": {"baseURL": $url}}' \
           "$OPENCODE_CONFIG_FILE" > "$TMP" && mv "$TMP" "$OPENCODE_CONFIG_FILE"
    fi

    print_success "llama.cpp provider added!"
fi
