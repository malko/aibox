#!/bin/bash

TARGET="${1:-}"
EXTRA="${2:-}"
SCRIPTS_DIR="$HOME/scripts"

NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <target> [options]"
    echo "Targets: opencode, opencode-password, dsh, os, vscode-server"
    exit 1
fi

case "$TARGET" in
    opencode)
        echo "Updating opencode..."
        if ! command -v npm &>/dev/null; then
            echo "Error: npm not found"
            exit 1
        fi
        npm install -g opencode-ai
        echo "Restarting opencode-web service..."
        systemctl --user restart opencode-web.service
        sleep 2
        systemctl --user status opencode-web.service --no-pager
        ;;
    opencode-password)
        "$SCRIPTS_DIR/install-service.sh"
        ;;
    os)
        echo "Updating system packages..."
        sudo apt update
        if [[ "$EXTRA" == "-y" || "$EXTRA" == "--yes" ]]; then
            echo "Running non-interactive dist-upgrade..."
            sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y dist-upgrade
        else
            sudo apt dist-upgrade
        fi
        if [[ -f /var/run/reboot-required ]]; then
            echo "Reboot required."
        fi
        ;;
    dsh)
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
        echo "Available targets: opencode, opencode-password, dsh, os, vscode-server"
        exit 1
        ;;
esac

# Refresh the cached update summary so the MOTD stays accurate after updating.
systemctl --user start --no-block aibox-update-check.service 2>/dev/null || true
