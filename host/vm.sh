#!/bin/bash
# Minimal VM helpers for the host-side tunnel service.
#
# This branch drives libvirt directly, like the rest of main. The macOS
# branch replaces this shim with host/backend.sh, which exposes the same
# vm_* function names (including vm_resolve/vm_ssh/vm_scp); host/tunnel.sh,
# cmd/status, cmd/exec and cmd/vscode only rely on this small set, so the
# swap is mechanical.
#
# Requires: shared-funcs.sh and config-funcs.sh sourced, init_config_file run.

vm_uri() {
    printf '%s\n' "${LIBVIRT_DEFAULT_URI:-$(get_config "LIBVIRT_DEFAULT_URI" "qemu:///system")}"
}

vm_exists() {
    virsh -c "$(vm_uri)" dominfo "$1" &>/dev/null
}

# Normalized states: running, shut off, paused, unknown.
# LC_ALL=C keeps virsh output in English: libvirt translates domain states
# (e.g. "en cours d'exécution" on a French locale), which would never match.
vm_state() {
    local state
    state=$(LC_ALL=C virsh -c "$(vm_uri)" domstate "$1" 2>/dev/null) || state=""
    if [[ -z "$state" ]]; then
        printf '%s\n' "unknown"
    else
        printf '%s\n' "$state"
    fi
}

vm_start() {
    virsh -c "$(vm_uri)" start "$1"
}

vm_ip() {
    virsh -c "$(vm_uri)" domifaddr "$1" --source lease 2>/dev/null \
        | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1
}

# SSH target resolved by vm_resolve; used by vm_ssh and vm_scp. The names and
# signatures match host/backend.sh on the macOS branch, so callers are
# backend-agnostic and survive the libvirt/lima swap.
VM_SSH_OPTS=()
VM_SSH_TARGET=""

# vm_resolve <vm_name>: sets VM_SSH_OPTS and VM_SSH_TARGET for that VM.
# Requires GUEST_USER (defaults to 'aibox').
vm_resolve() {
    local ip
    ip=$(vm_ip "$1")
    VM_SSH_OPTS=()
    VM_SSH_TARGET="${GUEST_USER:-aibox}@${ip}"
}

# vm_ssh runs ssh against the current VM. Everything before '--' is passed as
# ssh options, everything after is run as the remote command.
#
#   vm_ssh                                  # interactive shell
#   vm_ssh -L 8080:127.0.0.1:80             # interactive shell with forwarding
#   vm_ssh -t -t -- "~/scripts/foo.sh"      # run a command remotely
vm_ssh() {
    local opts=()
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--" ]]; then
            shift
            break
        fi
        opts+=("$1")
        shift
    done
    ssh "${VM_SSH_OPTS[@]}" "${opts[@]}" "$VM_SSH_TARGET" "$@"
}

# vm_scp runs scp against the current VM. The destination must be given as
# "$VM_SSH_TARGET:<path>", e.g.:
#   vm_scp file1 file2 "$VM_SSH_TARGET:~/scripts/"
vm_scp() {
    scp "${VM_SSH_OPTS[@]}" "$@"
}
