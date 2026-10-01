#!/bin/bash
set -e

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
init_config_file
source "$SCRIPT_DIR/host/backend.sh"

VM_NAME="${1:-$(get_config "VM_NAME" "aibox")}"

if [[ "$VM_BACKEND" == "lima" ]]; then
    GUEST_USER="$(vm_default_guest_user)"
else
    GUEST_USER=$(get_config "GUEST_USER" "aibox")
fi

if [[ "$(vm_state "$VM_NAME")" != "running" ]]; then
    print_error "VM '$VM_NAME' is not running."
    exit 1
fi

vm_resolve "$VM_NAME"

print_info "=== Upload Scripts to VM ==="

SCRIPT_FILES=(
    "$SCRIPT_DIR/shared-funcs.sh"
    "$SCRIPT_DIR/guest/install-deps.sh"
    "$SCRIPT_DIR/guest/install-docker.sh"
    "$SCRIPT_DIR/guest/install-service.sh"
    "$SCRIPT_DIR/guest/install-dsh.sh"
    "$SCRIPT_DIR/guest/install-dsh-service.sh"
    "$SCRIPT_DIR/guest/update-check.sh"
    "$SCRIPT_DIR/guest/install-update-check.sh"
    "$SCRIPT_DIR/guest/install-vscode.sh"
    "$SCRIPT_DIR/guest/configure-motd.sh"
    "$SCRIPT_DIR/guest/configure-sshd.sh"
    "$SCRIPT_DIR/guest/update-target.sh"
)

vm_ssh -- "mkdir -p ~/scripts"
vm_scp "${SCRIPT_FILES[@]}" "$VM_SSH_TARGET:~/scripts/"
vm_ssh -- "chmod +x ~/scripts/*.sh"

print_success "Scripts uploaded to VM!"
