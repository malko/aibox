#!/bin/bash
# sudo_cmd uses SUDO_PASSWORD supplied by the host for non-interactive setup
# steps (web UI). The CLI path has no SUDO_PASSWORD and keeps interactive sudo.

sudo_cmd() {
    if [[ -n "${SUDO_PASSWORD:-}" ]]; then
        printf '%s\n' "$SUDO_PASSWORD" | sudo -S -p '' "$@"
    else
        sudo "$@"
    fi
}
