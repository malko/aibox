#!/bin/bash
# Lima backend (macOS). Wraps limactl.
#
# The guest is reached through Lima's per-instance SSH config
# (~/.lima/<name>/ssh.config, alias lima-<name>), not through a routable guest
# IP: Lima uses user-mode networking, so 127.0.0.1:<port> is the only way in.

# lima_instance_field <name> <Field>: read one field from `limactl list`.
lima_instance_field() {
    local name="$1"
    local field="$2"
    limactl list "$name" --format "{{.$field}}" 2>/dev/null || true
}

vm_backend_require() {
    check_requirements limactl jq
}

vm_default_guest_user() {
    whoami
}

vm_exists() {
    limactl list --format '{{.Name}}' 2>/dev/null | grep -qx "$1"
}

# Normalized states: running, shut off, unknown. Lima also has transient states
# (Starting, Installing, Broken) that callers treat as "not running".
vm_state() {
    local status
    status=$(lima_instance_field "$1" "Status")
    case "$status" in
        Running) printf '%s\n' "running" ;;
        Stopped) printf '%s\n' "shut off" ;;
        *)       printf '%s\n' "unknown" ;;
    esac
}

vm_start() {
    limactl start "$1" --tty=false
}

vm_shutdown() {
    limactl stop "$1"
}

vm_destroy() {
    limactl stop --force "$1"
}

# The Lima disk is sparse; there is no guest-fstrim hook to run on the host.
vm_fstrim() {
    return 0
}

vm_ip() {
    lima_instance_field "$1" "IPAddress"
}

vm_ssh_ready() {
    local name="$1"
    [[ "$(vm_state "$name")" == "running" ]] || return 1
    vm_resolve "$name"
    vm_ssh -o BatchMode=yes -o ConnectTimeout=3 -- true &>/dev/null
}

# vm_wait_ready <name> [tries]: wait for the Lima instance to answer on SSH.
vm_wait_ready() {
    local name="$1"
    local tries="${2:-60}"
    local i
    for ((i = 0; i < tries; i++)); do
        if vm_ssh_ready "$name"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

vm_resolve() {
    local name="$1"
    local config
    config=$(lima_instance_field "$name" "SSHConfigFile")
    VM_SSH_OPTS=()
    if [[ -n "$config" && "$config" != "<no value>" ]]; then
        VM_SSH_OPTS=(-F "$config")
    fi
    VM_SSH_TARGET="lima-$name"
}

vm_create() {
    "$SCRIPT_DIR/host/create-vm-lima.sh" "$1"
}

# Lima injects this name (pointing at the host gateway) in the guest /etc/hosts.
vm_host_alias_ip() {
    printf '%s\n' "host.lima.internal"
}

# `limactl snapshot` exists since Lima 2.x but is still experimental; snapshots
# are intentionally not exposed on macOS yet.
vm_snapshot_supported() {
    return 1
}

vm_snapshot_list() {
    print_error "Snapshots are not supported on macOS (Lima backend)."
    return 1
}

vm_snapshot_create() {
    print_error "Snapshots are not supported on macOS (Lima backend)."
    return 1
}

vm_snapshot_delete() {
    print_error "Snapshots are not supported on macOS (Lima backend)."
    return 1
}

vm_snapshot_revert() {
    print_error "Snapshots are not supported on macOS (Lima backend)."
    return 1
}
