#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"
source "$SCRIPT_DIR/sudo-funcs.sh"

print_info "=== Configure SSH ==="

# sshd keeps the first value found and reads sshd_config.d/*.conf in lexical
# order, so this drop-in must sort before cloud-init's 50-cloud-init.conf.
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-aibox.conf"

print_info "Disabling password authentication..."
sudo_cmd sh -c 'printf "%s\n" "$1" "$2" > "$3"' _ \
    'PasswordAuthentication no' \
    'PermitRootLogin no' \
    "$SSHD_DROPIN"
sudo_cmd chmod 644 "$SSHD_DROPIN"

sudo_cmd systemctl reload ssh.service 2>/dev/null || sudo_cmd systemctl restart ssh.service

print_success "Password authentication disabled!"
