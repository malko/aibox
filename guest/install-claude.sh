#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Install Claude Code ==="

NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v npm &>/dev/null; then
    print_error "npm not found. Run install-deps.sh first."
    exit 1
fi

if command -v claude &>/dev/null; then
    print_info "Claude Code already installed: $(claude --version 2>/dev/null || echo unknown)"
else
    echo "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
fi

print_success "Claude Code installed!"
