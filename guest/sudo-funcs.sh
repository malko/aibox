#!/bin/bash
# sudo_cmd uses SUDO_PASSWORD supplied by the host for non-interactive setup
# steps (web UI). The CLI path has no SUDO_PASSWORD and keeps interactive sudo.
# Kept POSIX-compatible: setup/steps/hosts.sh sources this file from the guest
# login shell, which may be zsh or dash rather than bash.

sudo_cmd() {
    if [ -n "${SUDO_PASSWORD:-}" ]; then
        printf '%s\n' "$SUDO_PASSWORD" | sudo -S -p '' "$@"
    else
        sudo "$@"
    fi
}
