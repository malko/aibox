#!/bin/bash
set -e

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
init_config_file

check_command virsh

VM_NAME="${1:-$(get_config "VM_NAME" "aibox")}"
MAX_WAIT="${2:-30}"
LIBVIRT_DEFAULT_URI=$(get_config "LIBVIRT_DEFAULT_URI" "qemu:///system")

VM_STATE=$(virsh -c "$LIBVIRT_DEFAULT_URI" domstate "$VM_NAME" 2>/dev/null || echo "unknown")

NEEDS_BOOT=false

if [[ "$VM_STATE" == "running" ]]; then
    print_info "VM '$VM_NAME' is already running"
elif [[ "$VM_STATE" == "shut off" || "$VM_STATE" == "paused" ]]; then
    print_info "Starting VM '$VM_NAME'..."
    virsh -c "$LIBVIRT_DEFAULT_URI" start "$VM_NAME"
    NEEDS_BOOT=true
else
    print_error "VM '$VM_NAME' is in state: $VM_STATE"
    exit 1
fi

if [[ -f /tmp/aibox-vm-info ]]; then
    source /tmp/aibox-vm-info
fi

if [[ -n "$GUEST_IP" ]] && nc -z -w 1 "$GUEST_IP" 22 &>/dev/null; then
    print_success "VM is ready at $GUEST_IP"
    exit 0
fi

if [[ "$NEEDS_BOOT" == "false" && -z "$GUEST_IP" ]]; then
    print_info "No cached IP, getting current IP..."
elif [[ "$NEEDS_BOOT" == "true" ]]; then
    print_info "Waiting for VM to boot..."
    sleep 3
fi

for i in {1..15}; do
    GUEST_IP=$(virsh -c "$LIBVIRT_DEFAULT_URI" domifaddr "$VM_NAME" --source lease 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)
    if [[ -n "$GUEST_IP" ]]; then
        break
    fi
    if [[ "$NEEDS_BOOT" == "true" ]]; then
        echo -n "."
        sleep 2
    else
        sleep 0.5
    fi
done
[[ "$NEEDS_BOOT" == "true" ]] && echo ""

if [[ -z "$GUEST_IP" ]]; then
    print_error "Could not detect VM IP."
    exit 1
fi

print_success "VM IP: $GUEST_IP"

SSH_WAIT=1
if [[ "$NEEDS_BOOT" == "true" ]]; then
    print_info "Waiting for SSH..."
    SSH_WAIT=15
else
    print_info "Checking SSH..."
fi

for i in {1..15}; do
    if nc -z -w 1 "$GUEST_IP" 22 &>/dev/null; then
        print_success "SSH is ready!"
        break
    fi
    if [[ $i -lt $SSH_WAIT ]]; then
        sleep 1
    fi
done

if ! nc -z -w 1 "$GUEST_IP" 22 &>/dev/null; then
    print_error "SSH is not responding."
    exit 1
fi

echo "GUEST_IP=$GUEST_IP" > /tmp/aibox-vm-info
echo "VM_NAME=$VM_NAME" >> /tmp/aibox-vm-info

print_success "VM '$VM_NAME' is ready at $GUEST_IP"
