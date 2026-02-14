#!/bin/bash
set -e

source "$(dirname "$0")/../shared-funcs.sh"

check_command virsh
check_command virt-install

print_ascii_logo

HOSTNAME_LOCAL=$(hostname).local
print_info "=== Create New VM ==="
print_info "This script will create a new VM for AIBox"
print_info "Host detected: $HOSTNAME_LOCAL"
echo ""

VM_NAME="${1:-$(prompt "VM name" "aibox")}"

if virsh dominfo "$VM_NAME" &>/dev/null; then
    print_error "VM '$VM_NAME' already exists."
    exit 1
fi

print_info "=== VM Configuration ==="

ISO_PATH=$(prompt "Path to Ubuntu ISO" "")
VCPU=$(prompt "Number of CPUs" "4")
RAM=$(prompt "RAM in MB" "4096")
DISK_SIZE=$(prompt "Disk size (e.g., 20G)" "20G")
DISK_PATH=$(prompt "vm disk file path" "/var/lib/libvirt/images/${VM_NAME}.qcow2")
NETWORK=$(prompt "Network" "default")

print_info "Creating VM '$VM_NAME'..."

virt-install \
    --name "$VM_NAME" \
    --vcpus "$VCPU" \
    --ram "$RAM" \
    --disk path="${DISK_PATH},size=${DISK_SIZE}" \
    --os-variant ubuntu24.04 \
    --network network="$NETWORK" \
    --graphics none \
    --console pty,target_type=serial \
    --location "$ISO_PATH" \
    --extra-args 'console=ttyS0,115200n8 serial'

print_success "VM created!"
echo ""
print_warn "=== Next Steps ==="
print_info "1. Install Ubuntu LTS in the VM (use the console)"
print_info "2. Create a user account (e.g., 'aibox')"
print_info "3. After installation, restart the VM and run setup.sh again"
