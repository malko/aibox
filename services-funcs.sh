#!/bin/bash
# Per-service configuration and LAN exposure state.
#
# services.json is the persistent source of truth:
#   {
#     "opencode": { "port": "4096", "lan": "permanent" },
#     "dsh": { "port": "3080" }
#   }
# Legacy string values ("opencode": "4096") are still accepted.
#
# Temporary LAN exposure lives in a per-boot runtime file:
#   { "boot_id": "...", "services": { "dsh": { "until": 1760000000 } } }
# It is ignored when boot_id differs from the current boot, so a temporary
# exposure never survives a reboot even if the file itself does.

SERVICES_FILE="${SERVICES_FILE:-$HOME/.config/aibox/services.json}"
LAN_RUNTIME_FILE="${LAN_RUNTIME_FILE:-${XDG_RUNTIME_DIR:-$HOME/.cache}/aibox-lan.json}"

# Path to the tunnel CLI, used by the temporary-exposure timers. Resolved from
# this file so the helper also works from host/tunnel.sh and setup steps.
SERVICES_FUNCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIBOX_TUNNEL_CMD="${AIBOX_TUNNEL_CMD:-$SERVICES_FUNCS_DIR/cmd/tunnel}"

# Print an identifier that changes on every boot. Used to invalidate the
# temporary LAN state when it is stored on a filesystem that survives reboots.
system_boot_id() {
    if [[ -r /proc/sys/kernel/random/boot_id ]]; then
        tr -d '\n' < /proc/sys/kernel/random/boot_id
        return 0
    fi

    if [[ "$(uname -s)" == "Darwin" ]] && command -v sysctl &>/dev/null; then
        sysctl -n kern.boottime 2>/dev/null | tr -d '\n'
        return 0
    fi

    if [[ -r /proc/stat ]]; then
        awk '/^btime / { print $2; exit }' /proc/stat
        return 0
    fi

    printf '%s' "unknown"
}

services_require_jq() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required to manage aibox services." >&2
        return 1
    fi
}

# --- services.json ---------------------------------------------------------

# Rewrite legacy string entries as objects. Permanent LAN only is kept; any
# other value means localhost. The replacement is atomic so the tunnel service
# never reads a half-written file.
services_normalize() {
    [[ -f "$SERVICES_FILE" ]] || return 0

    # A zero-byte file is treated as an empty service map.
    if [[ ! -s "$SERVICES_FILE" ]]; then
        printf '{}\n' > "$SERVICES_FILE"
        return 0
    fi

    local tmp
    mkdir -p "$(dirname "$SERVICES_FILE")" || return 1
    tmp=$(mktemp "${SERVICES_FILE}.XXXXXX") || return 1

    if jq '
        with_entries(
            .value = (
                if (.value | type) == "object" then
                    ({ port: ((.value.port // "") | tostring) }
                     + (if .value.lan == "permanent" then { lan: "permanent" } else {} end))
                else
                    { port: (.value | tostring) }
                end
            )
        )
    ' "$SERVICES_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$SERVICES_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

# name<TAB>port, for both the object and the legacy string format.
services_entries() {
    [[ -f "$SERVICES_FILE" ]] || return 0
    jq -r '
        to_entries[]
        | [.key, (if (.value | type) == "object" then (.value.port // "") else (.value | tostring) end)]
        | @tsv
    ' "$SERVICES_FILE" 2>/dev/null
}

service_names() {
    [[ -f "$SERVICES_FILE" ]] || return 0
    jq -r 'keys[]' "$SERVICES_FILE" 2>/dev/null
}

service_exists() {
    local name="$1"
    [[ -f "$SERVICES_FILE" ]] || return 1
    jq -e --arg name "$name" 'has($name)' "$SERVICES_FILE" >/dev/null 2>&1
}

service_port() {
    local name="$1"
    [[ -f "$SERVICES_FILE" ]] || return 1
    jq -r --arg name "$name" '
        .[$name] | if type == "object" then (.port // empty) else . end
    ' "$SERVICES_FILE" 2>/dev/null
}

service_is_permanent() {
    local name="$1" mode
    [[ -f "$SERVICES_FILE" ]] || return 1
    mode=$(jq -r --arg name "$name" '
        .[$name] | if type == "object" then (.lan // "local") else "local" end
    ' "$SERVICES_FILE" 2>/dev/null)
    [[ "$mode" == "permanent" ]]
}

# service_set_lan <name> <permanent|local>
service_set_lan() {
    local name="$1" mode="$2" tmp
    mkdir -p "$(dirname "$SERVICES_FILE")" || return 1
    services_normalize || return 1

    [[ -f "$SERVICES_FILE" ]] || printf '{}\n' > "$SERVICES_FILE"
    tmp=$(mktemp "${SERVICES_FILE}.XXXXXX") || return 1

    if jq --arg name "$name" --arg mode "$mode" '
        .[$name] = (
            (.[$name] | if type == "object" then . else { port: (. | tostring) } end)
            | if $mode == "permanent" then . + { lan: "permanent" } else del(.lan) end
        )
    ' "$SERVICES_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$SERVICES_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

# service_add_json <name> <port> [permanent|local]
service_add_json() {
    local name="$1" port="$2" mode="${3:-local}" tmp
    mkdir -p "$(dirname "$SERVICES_FILE")" || return 1
    services_normalize || return 1

    [[ -f "$SERVICES_FILE" ]] || printf '{}\n' > "$SERVICES_FILE"
    tmp=$(mktemp "${SERVICES_FILE}.XXXXXX") || return 1

    if jq --arg name "$name" --arg port "$port" --arg mode "$mode" '
        .[$name] = ({ port: $port }
                    + (if $mode == "permanent" then { lan: "permanent" } else {} end))
    ' "$SERVICES_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$SERVICES_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

service_remove_json() {
    local name="$1" tmp
    services_normalize || return 1
    [[ -f "$SERVICES_FILE" ]] || return 0

    mkdir -p "$(dirname "$SERVICES_FILE")" || return 1
    tmp=$(mktemp "${SERVICES_FILE}.XXXXXX") || return 1

    if jq --arg name "$name" 'del(.[$name])' "$SERVICES_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$SERVICES_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

# --- temporary LAN state ---------------------------------------------------

_lan_runtime_reset() {
    local tmp boot
    mkdir -p "$(dirname "$LAN_RUNTIME_FILE")" || return 1
    boot=$(system_boot_id)
    tmp=$(mktemp "${LAN_RUNTIME_FILE}.XXXXXX") || return 1

    if jq -n --arg boot "$boot" '{ boot_id: $boot, services: {} }' > "$tmp"; then
        chmod 600 "$tmp" 2>/dev/null || true
        mv "$tmp" "$LAN_RUNTIME_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

# Drop expired entries and invalidate the whole file when the boot id changed.
lan_runtime_prune() {
    [[ -f "$LAN_RUNTIME_FILE" ]] || return 0

    local boot now tmp
    boot=$(system_boot_id)
    now=$(date +%s)
    mkdir -p "$(dirname "$LAN_RUNTIME_FILE")" || return 1
    tmp=$(mktemp "${LAN_RUNTIME_FILE}.XXXXXX") || return 1

    if ! jq --arg boot "$boot" --argjson now "$now" '
        if (.boot_id // "") != $boot then
            { boot_id: $boot, services: {} }
        else
            {
                boot_id: $boot,
                services: (
                    (.services // {})
                    | with_entries(select((.value.until // 0) == 0 or (.value.until // 0) > $now))
                )
            }
        end
    ' "$LAN_RUNTIME_FILE" > "$tmp" 2>/dev/null; then
        if ! jq -n --arg boot "$boot" '{ boot_id: $boot, services: {} }' > "$tmp"; then
            rm -f "$tmp"
            return 1
        fi
    fi

    chmod 600 "$tmp" 2>/dev/null || true
    mv "$tmp" "$LAN_RUNTIME_FILE"
}

# Names whose temporary exposure has expired. When the boot id changed, all
# temporary entries from the previous boot are reported as expired.
lan_runtime_expired_names() {
    [[ -f "$LAN_RUNTIME_FILE" ]] || return 0

    local boot now
    boot=$(system_boot_id)
    now=$(date +%s)

    jq -r --arg boot "$boot" --argjson now "$now" '
        if (.boot_id // "") != $boot then
            ((.services // {}) | keys[])
        else
            (.services // {})
            | to_entries[]
            | select((.value.until // 0) > 0 and (.value.until // 0) <= $now)
            | .key
        end
    ' "$LAN_RUNTIME_FILE" 2>/dev/null
}

lan_runtime_get_until() {
    local name="$1"
    [[ -f "$LAN_RUNTIME_FILE" ]] || return 0
    jq -r --arg name "$name" '.services[$name].until // empty' "$LAN_RUNTIME_FILE" 2>/dev/null
}

lan_runtime_is_active() {
    local name="$1" boot until now
    [[ -f "$LAN_RUNTIME_FILE" ]] || return 1

    boot=$(jq -r '.boot_id // empty' "$LAN_RUNTIME_FILE" 2>/dev/null)
    [[ -n "$boot" && "$boot" == "$(system_boot_id)" ]] || return 1

    until=$(lan_runtime_get_until "$name")
    [[ -n "$until" ]] || return 1
    [[ "$until" == "0" ]] && return 0
    [[ "$until" =~ ^[0-9]+$ ]] || return 1

    now=$(date +%s)
    (( until > now ))
}

# Schedule the automatic revert of one temporary exposure. The timer only
# removes the entry when its 'until' still matches, so a newer 'lan on' (or a
# permanent setting) is never clobbered by an old timer.
schedule_lan_expiry() {
    local name="$1" until="$2" seconds
    [[ "$until" =~ ^[0-9]+$ ]] && [[ "$until" -gt 0 ]] || return 0

    seconds=$(( until - $(date +%s) ))
    [[ "$seconds" -gt 0 ]] || return 0
    [[ -x "$AIBOX_TUNNEL_CMD" ]] || return 0

    if command -v systemd-run &>/dev/null && systemctl --user show-environment &>/dev/null; then
        systemd-run --user --on-active="${seconds}s" --collect \
            "$AIBOX_TUNNEL_CMD" lan expire "$name" "$until" >/dev/null 2>&1 && return 0
    fi

    # Fallback: a detached reverter (idempotent, lost on reboot; the lazy
    # check in enforce_lan_timeouts covers that case).
    nohup bash -c 'sleep "$1"; exec "$2" lan expire "$3" "$4"' _ \
        "$seconds" "$AIBOX_TUNNEL_CMD" "$name" "$until" >/dev/null 2>&1 &
}

# lan_runtime_set <name> <until-epoch|0>
lan_runtime_set() {
    local name="$1" until="$2" tmp
    [[ "$until" =~ ^[0-9]+$ ]] || return 1

    lan_runtime_prune
    [[ -f "$LAN_RUNTIME_FILE" ]] || _lan_runtime_reset || return 1

    mkdir -p "$(dirname "$LAN_RUNTIME_FILE")" || return 1
    tmp=$(mktemp "${LAN_RUNTIME_FILE}.XXXXXX") || return 1

    if jq --arg name "$name" --argjson until "$until" '
        .services[$name] = { until: $until }
    ' "$LAN_RUNTIME_FILE" > "$tmp" 2>/dev/null; then
        chmod 600 "$tmp" 2>/dev/null || true
        mv "$tmp" "$LAN_RUNTIME_FILE"
    else
        rm -f "$tmp"
        return 1
    fi

    schedule_lan_expiry "$name" "$until"
}

lan_runtime_remove() {
    local name="$1" tmp
    [[ -f "$LAN_RUNTIME_FILE" ]] || return 0

    lan_runtime_prune
    mkdir -p "$(dirname "$LAN_RUNTIME_FILE")" || return 1
    tmp=$(mktemp "${LAN_RUNTIME_FILE}.XXXXXX") || return 1

    if jq --arg name "$name" 'del(.services[$name])' "$LAN_RUNTIME_FILE" > "$tmp" 2>/dev/null; then
        chmod 600 "$tmp" 2>/dev/null || true
        mv "$tmp" "$LAN_RUNTIME_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

lan_runtime_clear() {
    _lan_runtime_reset
}

# --- effective mode --------------------------------------------------------

# service_effective_lan <name> -> permanent | temporary | local
service_effective_lan() {
    local name="$1"
    if service_is_permanent "$name"; then
        printf '%s\n' "permanent"
    elif lan_runtime_is_active "$name"; then
        printf '%s\n' "temporary"
    else
        printf '%s\n' "local"
    fi
}

service_lan_until() {
    local name="$1" until
    until=$(lan_runtime_get_until "$name")
    if [[ "$until" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$until"
    fi
    return 0
}

# --- legacy global mode migration ------------------------------------------

# Convert the old global TUNNEL_BIND/TUNNEL_LAN_UNTIL settings to per-service
# state, then reset them. host/tunnel.sh also honours the legacy settings until
# this migration has run, so an exposure is never lost during the upgrade.
services_migrate_legacy_global() {
    local bind="${TUNNEL_BIND:-local}"
    local until="${TUNNEL_LAN_UNTIL:-0}"
    [[ "$bind" == "lan" ]] || return 0

    local now name
    now=$(date +%s)

    if [[ "$until" =~ ^[0-9]+$ ]] && (( until > 0 )); then
        if (( until > now )); then
            while IFS= read -r name; do
                [[ -n "$name" ]] && lan_runtime_set "$name" "$until"
            done < <(service_names)
            print_info "Migrated global LAN exposure to temporary per-service settings."
        else
            print_info "Global LAN exposure had already expired; services are localhost-only."
        fi
    elif [[ "$until" == "0" || -z "$until" ]]; then
        while IFS= read -r name; do
            [[ -n "$name" ]] && service_set_lan "$name" permanent
        done < <(service_names)
        print_info "Migrated global LAN exposure to permanent per-service settings."
    fi

    # Also normalize legacy string entries when the service was only temporary.
    services_normalize || true

    save_config "TUNNEL_BIND" "local"
    save_config "TUNNEL_LAN_UNTIL" "0"
}
