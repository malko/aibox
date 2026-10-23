#!/bin/bash
set -e

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
init_config_file
source "$SCRIPT_DIR/host/backend.sh"

VM_NAME="${1:-$(get_config "VM_NAME" "aibox")}"
MAX_WAIT="${2:-30}"

if ! vm_exists "$VM_NAME"; then
    print_error "VM '$VM_NAME' does not exist."
    exit 1
fi

STATE=$(vm_state "$VM_NAME")

NEEDS_BOOT=false

if [[ "$STATE" == "running" ]]; then
    print_info "VM '$VM_NAME' is already running"
elif [[ "$STATE" == "shut off" || "$STATE" == "paused" ]]; then
    print_info "Starting VM '$VM_NAME'..."
    vm_start "$VM_NAME"
    NEEDS_BOOT=true
else
    print_error "VM '$VM_NAME' is in state: $STATE"
    exit 1
fi

# Bring the tunnel service up with the VM (a no-op when it is not installed,
# or when the service is already running).
"$SCRIPT_DIR/cmd/tunnel" ensure >/dev/null 2>&1 || true

GUEST_USER="${GUEST_USER:-$(vm_default_guest_user)}"
vm_resolve "$VM_NAME"

if vm_ssh_ready "$VM_NAME"; then
    save_vm_info "$VM_NAME" "$(vm_ip "$VM_NAME")"
    print_success "VM is ready at $VM_SSH_TARGET"
    exit 0
fi

if [[ "$NEEDS_BOOT" == "true" ]]; then
    print_info "Waiting for VM to boot..."
    sleep 3
fi

print_info "Waiting for SSH..."

if vm_wait_ready "$VM_NAME" "$MAX_WAIT"; then
    GUEST_IP=$(vm_ip "$VM_NAME")
    save_vm_info "$VM_NAME" "$GUEST_IP"
    print_success "VM '$VM_NAME' is ready at $VM_SSH_TARGET"
else
    print_error "VM '$VM_NAME' did not become reachable over SSH."
    exit 1
fi
