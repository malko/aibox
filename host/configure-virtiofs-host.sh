#!/bin/bash
set -e

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
init_config_file

check_command virsh
check_command virt-xml

LIBVIRT_DEFAULT_URI=$(get_config "LIBVIRT_DEFAULT_URI" "qemu:///system")

VM_NAME="${1:-aibox}"
HOST_SHARE_DIR="${2:-$HOME/git}"

print_info "=== Configure Virtiofs (Host) ==="

print_info "VM: $VM_NAME"
print_info "Share directory: $HOST_SHARE_DIR"

mkdir -p "$HOST_SHARE_DIR"

print_info "Checking existing filesystem configuration..."
DOMAIN_XML=$(virsh -c "$LIBVIRT_DEFAULT_URI" dumpxml "$VM_NAME")

if echo "$DOMAIN_XML" | grep -q "filesystem"; then
    print_warn "VM already has filesystem configured. Skipping."
    exit 0
fi

print_info "Shutting down VM..."
virsh -c "$LIBVIRT_DEFAULT_URI" shutdown "$VM_NAME" 2>/dev/null || true

STATE=""
for i in {1..30}; do
    STATE=$(virsh -c "$LIBVIRT_DEFAULT_URI" domstate "$VM_NAME" 2>/dev/null || echo "unknown")
    [[ "$STATE" == "shut off" ]] && break
    sleep 1
done

if [[ "$STATE" != "shut off" ]]; then
    print_error "VM did not shut down in time."
    exit 1
fi

print_info "Activating shared memory as it is mandatory for virtiofs..."
virt-xml --connect "$LIBVIRT_DEFAULT_URI" "$VM_NAME" --edit --memorybacking access.mode=shared,source.type=memfd

print_info "Adding filesystem to VM..."
virsh -c "$LIBVIRT_DEFAULT_URI" attach-device "$VM_NAME" --persistent --file /dev/stdin <<EOF
<filesystem type="mount" accessmode="passthrough">
  <driver type='virtiofs'/>
  <source dir="$HOST_SHARE_DIR"/>
  <target dir="gitshare"/>
</filesystem>
EOF


print_success "Virtiofs configured on host!"
