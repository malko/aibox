#!/bin/bash
# VM backend abstraction for aibox.
#
# Linux drives libvirt/QEMU through virsh, macOS drives Lima through limactl.
# Scripts talk to the VM through the vm_* helpers below instead of calling
# those tools directly, so the rest of aibox stays backend-agnostic.
#
# Callers must have sourced shared-funcs.sh and config-funcs.sh and must have
# called init_config_file before sourcing this file.

# vm_backend_detect prints the backend to use. An explicit VM_BACKEND config
# value wins; otherwise lima on macOS and libvirt elsewhere.
vm_backend_detect() {
    local configured
    configured=$(get_config "VM_BACKEND" "auto")
    case "$configured" in
        libvirt|lima)
            printf '%s\n' "$configured"
            ;;
        *)
            if is_macos; then
                printf '%s\n' "lima"
            else
                printf '%s\n' "libvirt"
            fi
            ;;
    esac
}

VM_BACKEND="$(vm_backend_detect)"
VM_BACKENDS_DIR="$SCRIPT_DIR/host/backends"

if [[ ! -f "$VM_BACKENDS_DIR/$VM_BACKEND.sh" ]]; then
    print_error "Unknown VM backend: '$VM_BACKEND' (expected 'libvirt' or 'lima')"
    exit 1
fi

# SSH target resolved by vm_resolve; used by vm_ssh.
VM_SSH_OPTS=()
VM_SSH_TARGET=""

# shellcheck source=host/backends/libvirt.sh
source "$VM_BACKENDS_DIR/$VM_BACKEND.sh"

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
