#!/bin/bash
set -e

source "$(dirname "$0")/../shared-funcs.sh"

check_command ssh
check_command ssh-copy-id

VM_NAME="${1:-}"

if [[ -f /tmp/aibox-vm-info ]]; then
    source /tmp/aibox-vm-info
fi

GUEST_IP="${2:-$GUEST_IP}"
GUEST_USER="${3:-$GUEST_USER}"

if [[ -z "$GUEST_IP" ]]; then
    GUEST_IP=$(prompt "Guest IP address" "")
fi

if [[ -z "$GUEST_USER" ]]; then
    GUEST_USER=$(prompt "VM username" "aibox")
fi

print_info "=== SSH Key Configuration ==="
print_info "Target: $GUEST_USER@$GUEST_IP"

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

if [[ ! -f "$SSH_KEY_PATH" || ! -f "${SSH_KEY_PATH}.pub" ]]; then
    print_info "No SSH key found. Creating new one..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
fi

print_info "Checking if SSH key authentication already works..."
if ssh -o ConnectTimeout=5 -o PasswordAuthentication=no "$GUEST_USER@$GUEST_IP" "echo 'SSH key auth works!'" &>/dev/null; then
    print_success "SSH key authentication already configured!"
    exit 0
fi

print_info "Copying SSH key to VM..."
if ! ssh-copy-id -i "${SSH_KEY_PATH}.pub" -o ConnectTimeout=10 "${GUEST_USER}@${GUEST_IP}" 2>/dev/null; then
    print_error "Failed to copy SSH key. Make sure you can connect with password."
    exit 1
fi

print_info "Verifying SSH key authentication..."
if ssh -o ConnectTimeout=10 -o PasswordAuthentication=no "$GUEST_USER@$GUEST_IP" "echo 'SSH key auth works!'" &>/dev/null; then
    print_success "SSH key authentication verified!"
else
    print_error "SSH key authentication failed."
    exit 1
fi
