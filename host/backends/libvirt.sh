#!/bin/bash
# libvirt/QEMU backend (Linux). Wraps virsh and the existing host scripts.

libvirt_uri() {
    printf '%s\n' "${LIBVIRT_DEFAULT_URI:-$(get_config "LIBVIRT_DEFAULT_URI" "qemu:///system")}"
}

vm_backend_require() {
    check_requirements virsh jq
}

vm_default_guest_user() {
    printf '%s\n' "aibox"
}

vm_exists() {
    virsh -c "$(libvirt_uri)" dominfo "$1" &>/dev/null
}

# Normalized states: running, shut off, paused, unknown.
# LC_ALL=C keeps virsh output in English: libvirt translates domain states
# (e.g. "en cours d'exécution" on a French locale), which would never match.
vm_state() {
    local state
    state=$(LC_ALL=C virsh -c "$(libvirt_uri)" domstate "$1" 2>/dev/null) || state=""
    if [[ -z "$state" ]]; then
        printf '%s\n' "unknown"
    else
        printf '%s\n' "$state"
    fi
}

vm_start() {
    virsh -c "$(libvirt_uri)" start "$1"
}

vm_shutdown() {
    virsh -c "$(libvirt_uri)" shutdown "$1"
}

vm_destroy() {
    virsh -c "$(libvirt_uri)" destroy "$1"
}

# Best-effort TRIM inside the guest to reclaim space in the qcow2 image.
# Fails quietly when the QEMU guest agent is not responding.
vm_fstrim() {
    virsh -c "$(libvirt_uri)" qemu-agent-command "$1" '{"execute":"guest-fstrim"}' >/dev/null 2>&1
}

vm_ip() {
    virsh -c "$(libvirt_uri)" domifaddr "$1" --source lease 2>/dev/null \
        | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1
}

vm_ssh_ready() {
    local ip
    ip=$(vm_ip "$1")
    [[ -n "$ip" ]] && port_open "$ip" 22
}

# vm_wait_ready <name> [tries]: wait for a guest IP and an open SSH port.
vm_wait_ready() {
    local name="$1"
    local tries="${2:-20}"
    local i ip
    for ((i = 0; i < tries; i++)); do
        ip=$(vm_ip "$name")
        if [[ -n "$ip" ]] && port_open "$ip" 22; then
            return 0
        fi
        sleep 1
    done
    return 1
}

vm_resolve() {
    local name="$1"
    local ip
    ip=$(vm_ip "$name")
    VM_SSH_OPTS=()
    VM_SSH_TARGET="${GUEST_USER:-aibox}@${ip}"
}

vm_create() {
    "$SCRIPT_DIR/host/create-vm.sh" "$1"
}

# Address the guest uses to reach the host (libvirt default network gateway).
vm_host_alias_ip() {
    printf '%s\n' "192.168.122.1"
}

vm_configure_share() {
    "$SCRIPT_DIR/host/configure-virtiofs-host.sh" "$1" "$2"
}

vm_snapshot_supported() {
    return 0
}

vm_snapshot_list() {
    virsh -c "$(libvirt_uri)" snapshot-list "$1" --name 2>/dev/null
}

vm_snapshot_create() {
    virsh -c "$(libvirt_uri)" snapshot-create-as "$1" "$2"
}

vm_snapshot_delete() {
    virsh -c "$(libvirt_uri)" snapshot-delete "$1" "$2" --metadata 2>/dev/null || \
        virsh -c "$(libvirt_uri)" snapshot-delete "$1" "$2"
}

vm_snapshot_revert() {
    virsh -c "$(libvirt_uri)" snapshot-revert "$1" "$2"
}
