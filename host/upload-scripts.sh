#!/bin/bash
set -e

source "$(dirname "$0")/../shared-funcs.sh"

VM_NAME="${1:-}"

load_vm_info "$VM_NAME"

GUEST_IP="${2:-$GUEST_IP}"
GUEST_USER="${3:-$GUEST_USER}"

if [[ -z "$GUEST_IP" ]]; then
    GUEST_IP=$(prompt "Guest IP address" "")
fi

if [[ -z "$GUEST_USER" ]]; then
    GUEST_USER=$(prompt "VM username" "aibox")
fi

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

print_info "=== Upload Scripts to VM ==="

scp -o ConnectTimeout=10 \
    "$SCRIPT_DIR/shared-funcs.sh" \
    "$SCRIPT_DIR/guest/install-deps.sh" \
    "$SCRIPT_DIR/guest/install-docker.sh" \
    "$SCRIPT_DIR/guest/install-service.sh" \
    "$SCRIPT_DIR/guest/install-vscode.sh" \
    "$SCRIPT_DIR/guest/configure-motd.sh" \
    "$SCRIPT_DIR/guest/configure-sshd.sh" \
    "$SCRIPT_DIR/guest/configure-llm.sh" \
    "$SCRIPT_DIR/guest/update-opencode-models.sh" \
    "$SCRIPT_DIR/guest/update-target.sh" \
    "$GUEST_USER@${GUEST_IP}:~/scripts/"

ssh -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "chmod +x ~/scripts/*.sh"

print_success "Scripts uploaded to VM!"
