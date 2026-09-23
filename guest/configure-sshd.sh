#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Configure SSH ==="

# sshd keeps the first value found and reads sshd_config.d/*.conf in lexical
# order, so this drop-in must sort before cloud-init's 50-cloud-init.conf.
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-aibox.conf"

print_info "Disabling password authentication..."
printf '%s\n' \
    'PasswordAuthentication no' \
    'PermitRootLogin no' \
    | sudo tee "$SSHD_DROPIN" > /dev/null
sudo chmod 644 "$SSHD_DROPIN"

sudo systemctl reload ssh.service 2>/dev/null || sudo systemctl restart ssh.service

print_success "Password authentication disabled!"
