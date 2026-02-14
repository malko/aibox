#!/bin/bash
set -e

source "$(dirname "$0")/../shared-funcs.sh"

check_command virsh

VM_NAME="${1:-aibox}"
HOST_SHARE_DIR="${2:-$HOME/git}"

if [[ -f /tmp/aibox-vm-info ]]; then
    source /tmp/aibox-vm-info
fi

print_info "=== Configure Virtiofs (Host) ==="

print_info "VM: $VM_NAME"
print_info "Share directory: $HOST_SHARE_DIR"

mkdir -p "$HOST_SHARE_DIR"

print_info "Shutting down VM..."
virsh shutdown "$VM_NAME" 2>/dev/null || true
sleep 3

print_info "Checking existing filesystem configuration..."
DOMAIN_XML=$(virsh dumpxml "$VM_NAME")

if echo "$DOMAIN_XML" | grep -q "filesystem"; then
    print_warn "VM already has filesystem configured. Skipping."
    exit 0
fi

print_info "Adding filesystem to VM..."
virsh attach-device "$VM_NAME" --persistent --file - <<EOF
<filesystem type="mount" accessmode="passthrough">
  <source dir="$HOST_SHARE_DIR"/>
  <target dir="git-share"/>
</filesystem>
EOF

print_success "Virtiofs configured on host!"
print_info "Now run guest/configure-virtiofs-guest.sh inside the VM to complete setup."
