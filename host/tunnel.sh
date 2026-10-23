#!/bin/bash
# Maintains the SSH tunnel that exposes the configured VM services on the host.
#
# Started by the aibox-tunnel user service. It waits (bounded by TUNNEL_WAIT)
# for the VM, which is always started by the CLI (aibox start/connect/restart),
# never by this service. It then execs a single `ssh -N` with one -L per
# configured service. A non-zero exit makes the service manager restart it; a
# clean exit (VM still off after the wait) leaves the service inactive, so an
# idle VM costs nothing.
#
# LAN exposure is decided per service: permanent services are stored in
# services.json, temporary ones in the per-boot runtime file. Each service gets
# its own bind address, so opencode can be on the LAN while dsh stays local.

set -e

CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
source "$(dirname "$0")/../shared-funcs.sh"
source "$(dirname "$0")/../config-funcs.sh"
source "$(dirname "$0")/../services-funcs.sh"
init_config_file
source "$SCRIPT_DIR/host/backend.sh"

VM_NAME=$(get_config "VM_NAME" "aibox")
if [[ "$VM_BACKEND" == "lima" ]]; then
    GUEST_USER="$(vm_default_guest_user)"
else
    GUEST_USER=$(get_config "GUEST_USER" "aibox")
fi
TUNNEL_WAIT=$(get_config "TUNNEL_WAIT" "120")

# Legacy global bind. It is migrated to per-service settings by cmd/tunnel, but
# this service may start before any CLI command runs; honour it in the meantime
# so an exposure configured before the upgrade is not lost.
TUNNEL_BIND=$(get_config "TUNNEL_BIND" "local")
TUNNEL_LAN_UNTIL=$(get_config "TUNNEL_LAN_UNTIL" "0")
LEGACY_LAN=false
if [[ "$TUNNEL_BIND" == "lan" ]]; then
    if [[ "$TUNNEL_LAN_UNTIL" =~ ^[0-9]+$ ]] && [[ "$TUNNEL_LAN_UNTIL" -gt 0 ]]; then
        [[ "$(date +%s)" -lt "$TUNNEL_LAN_UNTIL" ]] && LEGACY_LAN=true
    else
        LEGACY_LAN=true
    fi
fi

# A user service does not always inherit the shell PATH: fail loudly instead
# of reporting "no services" and exiting cleanly (which leaves the tunnel
# silently inactive).
if ! command -v jq &>/dev/null; then
    echo "jq not found in PATH ($PATH): cannot read $SERVICES_FILE." >&2
    exit 1
fi

# Drop expired temporary exposures (or all of them after a reboot).
lan_runtime_prune || true

FORWARD_ARGS=()
PORTS_DESC=()
SERVICE_COUNT=0

while IFS=$'\t' read -r name port; do
    [[ -n "$name" && -n "$port" ]] || continue

    if [[ "$port" == *:* ]]; then
        HOST_PORT="${port%%:*}"
        GUEST_PORT="${port#*:}"
    else
        HOST_PORT="$port"
        GUEST_PORT="$port"
    fi

    MODE=$(service_effective_lan "$name")
    BIND="127.0.0.1"
    if [[ "$MODE" != "local" || "$LEGACY_LAN" == "true" ]]; then
        BIND="0.0.0.0"
    fi

    FORWARD_ARGS+=(-L "$BIND:$HOST_PORT:127.0.0.1:$GUEST_PORT")
    PORTS_DESC+=("$name=$BIND:$HOST_PORT")
    SERVICE_COUNT=$((SERVICE_COUNT + 1))
done < <(services_entries)

if [[ "$SERVICE_COUNT" -eq 0 ]]; then
    echo "No services configured; nothing to tunnel."
    exit 0
fi

vm_running() {
    vm_exists "$VM_NAME" && [[ "$(vm_state "$VM_NAME")" == "running" ]]
}

DEADLINE=$(( $(date +%s) + TUNNEL_WAIT ))

while ! vm_running; do
    if [[ "$(date +%s)" -ge "$DEADLINE" ]]; then
        last_state=$(vm_state "$VM_NAME")
        if [[ "$last_state" == "shut off" ]]; then
            echo "VM '$VM_NAME' is shut off; stopping the tunnel service (no polling)."
            exit 0
        fi
        # Unknown/error state: keep the service alive so the manager retries
        # instead of silently giving up while the VM may still be running.
        echo "VM '$VM_NAME' is not reachable (state: ${last_state:-unknown}); retrying." >&2
        exit 1
    fi
    sleep 3
done

vm_resolve "$VM_NAME"
if [[ -z "$VM_SSH_TARGET" ]]; then
    echo "Could not resolve the SSH target for '$VM_NAME'." >&2
    exit 1
fi

echo "Tunnel up: ${PORTS_DESC[*]}"

# -N: no remote command/shell (without it ssh opens a shell, prints the MOTD
# and exits 0, leaving the service silently inactive).
# -n: never read from stdin (the unit runs without a terminal).
exec ssh -N -n "${VM_SSH_OPTS[@]}" \
    -o ExitOnForwardFailure=yes \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    "${FORWARD_ARGS[@]}" \
    "$VM_SSH_TARGET"
