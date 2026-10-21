#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sudo-funcs.sh"

TARGET="${1:-}"
EXTRA="${2:-}"
SCRIPTS_DIR="$HOME/scripts"

NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ] && [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
fi

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <target> [options]"
    echo "Targets: opencode, opencode-service, dsh, claude, os, vscode-server"
    exit 1
fi

case "$TARGET" in
    opencode)
        if ! command -v opencode &>/dev/null; then
            echo "opencode not installed, skipping"
            exit 0
        fi
        echo "Updating opencode..."
        if ! opencode update; then
            echo "Error: opencode update failed" >&2
            exit 1
        fi
        echo "Restarting opencode server..."
        systemctl --user restart opencode.service
        sleep 2
        systemctl --user status opencode.service --no-pager
        ;;
    opencode-service)
        "$SCRIPTS_DIR/install-service.sh" "$EXTRA"
        ;;
    os)
        echo "Updating system packages..."
        sudo_cmd apt update
        if [[ "$EXTRA" == "-y" || "$EXTRA" == "--yes" ]]; then
            echo "Running non-interactive dist-upgrade..."
            sudo_cmd env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y dist-upgrade
        else
            sudo_cmd apt dist-upgrade
        fi
        if [[ -f /var/run/reboot-required ]]; then
            echo "Reboot required."
        fi
        ;;
    dsh)
        if ! command -v dsh &>/dev/null; then
            echo "dsh not installed, skipping"
            exit 0
        fi
        echo "Updating dsh..."
        if ! command -v npm &>/dev/null; then
            echo "Error: npm not found"
            exit 1
        fi
        npm install -g @deepseek-ai/dsh@latest
        echo "Restarting dsh-web service..."
        systemctl --user restart dsh-web.service
        sleep 2
        systemctl --user status dsh-web.service --no-pager
        ;;
    claude)
        if ! command -v claude &>/dev/null; then
            echo "Claude Code not installed, skipping"
            exit 0
        fi
        echo "Updating Claude Code..."
        if ! command -v npm &>/dev/null; then
            echo "Error: npm not found"
            exit 1
        fi
        npm install -g @anthropic-ai/claude-code@latest
        ;;
    vscode-server)
        cd "$HOME/vscode-server"
        if [[ -f "$HOME/vscode-server/docker-compose.yml" ]]; then
            docker compose pull
            docker compose down
            docker compose up -d
        else
            echo "vscode-server not installed"
        fi
        ;;
    *)
        echo "Unknown target: $TARGET"
        echo "Available targets: opencode, opencode-service, dsh, claude, os, vscode-server"
        exit 1
        ;;
esac

# Refresh the cached update summary so the MOTD stays accurate after updating.
systemctl --user start --no-block aibox-update-check.service 2>/dev/null || true
