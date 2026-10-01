#!/bin/bash
set -e

# Create and start the AIBox VM with Lima (macOS).
# Called by the Lima backend (vm_create); not meant to be run directly on
# Linux hosts unless VM_BACKEND=lima is explicitly configured.

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
init_config_file
source "$SCRIPT_DIR/host/backend.sh"

check_command limactl

print_ascii_logo

HOSTNAME_LOCAL=$(host_local_name)
print_info "=== Create New VM (Lima) ==="
print_info "This will create an Ubuntu VM managed by Lima."
print_info "Host detected: $HOSTNAME_LOCAL"
echo ""

VM_NAME="${1:-$(prompt "VM name" "aibox")}"

if vm_exists "$VM_NAME"; then
    print_error "VM '$VM_NAME' already exists."
    exit 1
fi

print_info "=== VM Configuration (press Enter for defaults) ==="

VCPU=$(prompt "Number of CPUs" "4")
MEMORY=$(prompt "RAM in GiB" "4")
DISK=$(prompt "Disk size in GiB" "20")

if [[ ! "$VCPU" =~ ^[0-9]+$ ]] || [[ ! "$MEMORY" =~ ^[0-9]+$ ]] || [[ ! "$DISK" =~ ^[0-9]+$ ]]; then
    print_error "CPUs, RAM and disk size must be numbers."
    exit 1
fi

# Host directory shared with the guest (declared in the Lima template).
HOST_SHARE_DIR="$HOME/git"
mkdir -p "$HOST_SHARE_DIR"
print_info "Host directory $HOST_SHARE_DIR will be shared at ~/git in the VM."

TEMPLATE="$SCRIPT_DIR/host/lima/aibox.yaml"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aibox-lima.XXXXXX")"
TMP_TEMPLATE="$TMP_DIR/aibox.yaml"
trap 'rm -rf "$TMP_DIR"' EXIT

sed -e "s/__CPUS__/$VCPU/" \
    -e "s/__MEMORY__/${MEMORY}GiB/" \
    -e "s/__DISK__/${DISK}GiB/" \
    "$TEMPLATE" > "$TMP_TEMPLATE"

print_info "Creating and starting the Lima instance '$VM_NAME'..."
print_info "The first boot can take several minutes (Ubuntu image download)."
limactl start --name="$VM_NAME" --tty=false "$TMP_TEMPLATE"

print_success "VM '$VM_NAME' created and running!"
print_info "The aibox setup will continue inside the VM."
