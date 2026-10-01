#!/bin/bash
# Maintains the SSH tunnel that exposes the configured VM services on the host.
#
# Started by the aibox-tunnel user service. It waits (bounded by TUNNEL_WAIT)
# for the VM, then execs a single `ssh -N` with one -L per configured service.
# A non-zero exit makes the service manager restart it (Restart=on-failure); a
# clean exit (VM still off after the wait) leaves the service inactive, so an
# idle VM costs nothing.

set -e

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
init_config_file
source "$SCRIPT_DIR/host/vm.sh"

VM_NAME=$(get_config "VM_NAME" "aibox")
GUEST_USER=$(get_config "GUEST_USER" "aibox")
TUNNEL_BIND=$(get_config "TUNNEL_BIND" "local")
TUNNEL_START_VM=$(get_config "TUNNEL_START_VM" "no")
TUNNEL_WAIT=$(get_config "TUNNEL_WAIT" "120")

# Enforce the LAN timeout even when the service is started at login (the lazy
# check in cmd/tunnel covers interactive use).
TUNNEL_LAN_UNTIL=$(get_config "TUNNEL_LAN_UNTIL" "0")
if [[ "$TUNNEL_BIND" == "lan" && "$TUNNEL_LAN_UNTIL" =~ ^[0-9]+$ ]] \
    && [[ "$TUNNEL_LAN_UNTIL" -gt 0 ]] \
    && [[ "$(date +%s)" -ge "$TUNNEL_LAN_UNTIL" ]]; then
    TUNNEL_BIND="local"
fi

SERVICES_FILE="${HOME}/.config/aibox/services.json"

PORTS=()
if [[ -f "$SERVICES_FILE" ]]; then
    while IFS= read -r port; do
        [[ -n "$port" ]] && PORTS+=("$port")
    done < <(jq -r 'to_entries[] | .value' "$SERVICES_FILE" 2>/dev/null || true)
fi

if [[ ${#PORTS[@]} -eq 0 ]]; then
    echo "No services configured; nothing to tunnel."
    exit 0
fi

BIND="127.0.0.1"
if [[ "$TUNNEL_BIND" == "lan" ]]; then
    BIND="0.0.0.0"
fi

vm_running() {
    vm_exists "$VM_NAME" && [[ "$(vm_state "$VM_NAME")" == "running" ]]
}

DEADLINE=$(( $(date +%s) + TUNNEL_WAIT ))

if ! vm_running; then
    if [[ "$TUNNEL_START_VM" == "yes" ]] && vm_exists "$VM_NAME"; then
        echo "VM '$VM_NAME' is not running; starting it..."
        vm_start "$VM_NAME" || true
        DEADLINE=$(( $(date +%s) + TUNNEL_WAIT ))
    fi
fi

while ! vm_running; do
    if [[ "$(date +%s)" -ge "$DEADLINE" ]]; then
        echo "VM '$VM_NAME' is not running; stopping the tunnel service (no polling)."
        exit 0
    fi
    sleep 3
done

GUEST_IP=$(vm_ip "$VM_NAME")
if [[ -z "$GUEST_IP" ]]; then
    echo "Could not determine the guest IP." >&2
    exit 1
fi

FORWARD_ARGS=()
for ARG in "${PORTS[@]}"; do
    if [[ "$ARG" == *:* ]]; then
        HOST_PORT="${ARG%%:*}"
        GUEST_PORT="${ARG#*:}"
    else
        HOST_PORT="$ARG"
        GUEST_PORT="$ARG"
    fi
    FORWARD_ARGS+=(-L "$BIND:$HOST_PORT:127.0.0.1:$GUEST_PORT")
done

echo "Tunnel up on $BIND -> $GUEST_IP (${PORTS[*]})"

exec ssh -o ExitOnForwardFailure=yes \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    "${FORWARD_ARGS[@]}" \
    "$GUEST_USER@$GUEST_IP"
