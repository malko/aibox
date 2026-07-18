#!/bin/bash
set -e

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
init_config_file

LIBVIRT_DEFAULT_URI=$(get_config "LIBVIRT_DEFAULT_URI" "qemu:///system")

check_command virsh
check_command virt-install

print_ascii_logo

HOSTNAME_LOCAL=$(hostname).local
print_info "=== Create New VM ==="
print_info "This script will create a new VM for AIBox"
print_info "Host detected: $HOSTNAME_LOCAL"
echo ""

VM_NAME="${1:-$(prompt "VM name" "aibox")}"

if virsh -c "$LIBVIRT_DEFAULT_URI" dominfo "$VM_NAME" &>/dev/null; then
    print_error "VM '$VM_NAME' already exists."
    exit 1
fi

print_info "=== VM Configuration ==="

ISO_PATH=$(prompt "Path to Ubuntu ISO" "")
VCPU=$(prompt "Number of CPUs" "4")
RAM=$(prompt "RAM in MB" "4096")
DISK_SIZE=$(prompt "Disk size in GB (e.g., 20)" "20")
DISK_PATH=$(prompt "vm disk file path" "/var/lib/libvirt/images/${VM_NAME}.qcow2")
NETWORK=$(prompt "Network" "default")

print_info "Creating VM '$VM_NAME'..."

# TODO check for default network or try to create if from virsh net-define /usr/share/libvirt/networks/default.xml
virsh -c "$LIBVIRT_DEFAULT_URI" net-info default >/dev/null 2>&1 || echo "Error: network 'default' does not exist."
if [ "$(virsh -c "$LIBVIRT_DEFAULT_URI" net-info default | grep 'Active' | awk '{print $2}')" = "no" ]; then
    virsh -c "$LIBVIRT_DEFAULT_URI" net-start default
    echo "Network 'default' started."
fi

virt-install \
    --connect "$LIBVIRT_DEFAULT_URI" \
    --name "$VM_NAME" \
    --vcpus "$VCPU" \
    --ram "$RAM" \
    --disk path="${DISK_PATH},size=${DISK_SIZE}" \
    --os-variant ubuntu24.04 \
    --network network="$NETWORK" \
    --graphics none \
    --console pty,target_type=serial \
    --location "$ISO_PATH",kernel=casper/vmlinuz,initrd=casper/initrd \
    --extra-args 'console=ttyS0,115200n8 serial'

print_success "VM created!"
echo ""
print_warn "=== Next Steps ==="
print_info "1. Install Ubuntu LTS in the VM (use the console)"
print_info "2. Create a user account (e.g., 'aibox')"
print_info "3. After installation, restart the VM and run setup.sh again"
