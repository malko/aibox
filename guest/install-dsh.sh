#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Install dsh (DeepSeek Harness) ==="

NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
    echo "==> NVM detected: $NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

if ! command -v npm &>/dev/null; then
    print_error "npm not found. Run install-deps.sh first."
    exit 1
fi

if command -v dsh &>/dev/null; then
    print_info "dsh already installed: $(dsh --version 2>/dev/null)"
else
    echo "==> Installing dsh..."
    npm install -g @deepseek-ai/dsh
fi

print_success "dsh installed!"
