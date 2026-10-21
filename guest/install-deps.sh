#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"
source "$SCRIPT_DIR/sudo-funcs.sh"

print_info "=== Install Dependencies ==="

echo "Updating packages..."
sudo_cmd apt update
sudo_cmd apt install -y curl jq netcat-openbsd git qemu-guest-agent shellcheck

if ! command -v nvm &>/dev/null && [ ! -d "$HOME/.nvm" ]; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
    echo "Installing Node.js..."
    nvm install 24
    nvm use 24
fi

if ! npm ls -g @opencode/cli &>/dev/null; then
    echo "Installing opencode v2..."
    npm install -g @opencode/cli
fi

echo "Dependencies installed!"

print_success "Dependencies installed!"
