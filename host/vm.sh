#!/bin/bash
# Minimal VM helpers for the host-side tunnel service.
#
# This branch drives libvirt directly, like the rest of main. The macOS
# branch replaces this shim with host/backend.sh, which exposes the same
# vm_* function names; host/tunnel.sh and cmd/status only rely on this small
# set, so the swap is mechanical.
#
# Requires: shared-funcs.sh and config-funcs.sh sourced, init_config_file run.

vm_uri() {
    printf '%s\n' "${LIBVIRT_DEFAULT_URI:-$(get_config "LIBVIRT_DEFAULT_URI" "qemu:///system")}"
}

vm_exists() {
    virsh -c "$(vm_uri)" dominfo "$1" &>/dev/null
}

# Normalized states: running, shut off, paused, unknown.
vm_state() {
    local state
    state=$(virsh -c "$(vm_uri)" domstate "$1" 2>/dev/null) || state=""
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
