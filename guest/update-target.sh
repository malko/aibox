#!/bin/bash

TARGET="${1:-}"
SCRIPTS_DIR="$HOME/scripts"

NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <target>"
    echo "Targets: opencode, opencode-password"
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
    *)
        echo "Unknown target: $TARGET"
        echo "Available targets: opencode"
        exit 1
        ;;
esac