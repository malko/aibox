#!/bin/bash
# shellcheck disable=SC2016  # $HOME is expanded by the guest shell
# Inspect and restart the services installed in the VM for the web console.
#
# This is an internal helper (like open-terminal.sh), not a public aibox
# command. It reports the systemd user units (opencode.service,
# dsh-web.service) and the vscode-server Docker container, plus their
# connection details and journal/container logs.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIBOX_ROOT="${AIBOX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CONFIG_FILE="$HOME/.config/aibox/aibox.conf"

usage_system_service() {
    echo "Usage: system-service.sh <list|info|logs|restart> [name] [options]"
    echo ""
    echo "Inspect or restart the services installed inside the VM:"
    echo "  opencode       opencode.service"
    echo "  dsh-web        dsh-web.service"
    echo "  vscode-server  vscode-server Docker container"
    echo ""
    echo "Commands:"
    echo "  list                 List the installed services"
    echo "  info <name>          Show status and connection details"
    echo "  logs <name>          Show the most recent logs"
    echo "  restart <name>       Restart the service"
    echo ""
    echo "Options:"
    echo "  --json               Machine-readable JSON (list and info)"
    echo "  --lines N            Number of log lines, default 200 (logs)"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Internal helper for the AIBox web console."
}

parse_system_service_args() {
    ACTION="list"
    NAME=""
    JSON_MODE=false
    LOG_LINES=200
    POSITIONAL=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage_system_service
                exit 0
                ;;
            --json)
                JSON_MODE=true
                shift
                ;;
            --lines)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --lines requires a number" >&2
                    exit 1
                fi
                LOG_LINES="$2"
                shift 2
                ;;
            --lines=*)
                LOG_LINES="${1#*=}"
                shift
                ;;
            list|info|logs|restart)
                ACTION="$1"
                shift
                ;;
            -*)
                echo "Error: unknown option: $1" >&2
                usage_system_service >&2
                exit 1
                ;;
            *)
                POSITIONAL+=("$1")
                shift
                ;;
        esac
    done

    NAME="${POSITIONAL[0]:-}"
    if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
        echo "Error: too many arguments" >&2
        exit 1
    fi
    if [[ "$ACTION" == "list" && -n "$NAME" ]]; then
        echo "Error: 'list' does not take a service name" >&2
        exit 1
    fi
    if [[ "$ACTION" != "list" && -z "$NAME" ]]; then
        echo "Error: '$ACTION' requires a service name" >&2
        exit 1
    fi
    if [[ -n "$NAME" ]] && ! unit_is_known "$NAME"; then
        echo "Error: unknown service: $NAME" >&2
        echo "Available services: opencode, dsh-web, vscode-server" >&2
        exit 1
    fi
    if [[ ! "$LOG_LINES" =~ ^[0-9]+$ ]]; then
        echo "Error: --lines requires a number" >&2
        exit 1
    fi
}

unit_is_known() {
    case "$1" in
        opencode|dsh-web|vscode-server) return 0 ;;
        *) return 1 ;;
    esac
}

source "$AIBOX_ROOT/shared-funcs.sh"
source "$AIBOX_ROOT/config-funcs.sh"
source "$AIBOX_ROOT/services-funcs.sh"
init_config_file
source "$AIBOX_ROOT/host/backend.sh"

parse_system_service_args "$@"

VM_NAME=$(get_config "VM_NAME" "aibox")

if [[ "$(vm_state "$VM_NAME")" != "running" ]]; then
    echo "the VM is not running" >&2
    exit 1
fi

vm_resolve "$VM_NAME"
if [[ "$VM_SSH_TARGET" == *@ ]]; then
    echo "could not detect the guest IP" >&2
    exit 1
fi

ensure_guest_script() {
    if vm_ssh -n -o BatchMode=yes -o ConnectTimeout=5 -- \
        'test -f "$HOME/scripts/system-service.sh"' 2>/dev/null; then
        return 0
    fi

    vm_ssh -n -o ConnectTimeout=10 -- 'mkdir -p "$HOME/scripts"' 2>/dev/null || true
    vm_scp -q -o ConnectTimeout=10 \
        "$AIBOX_ROOT/guest/system-service.sh" \
        "$VM_SSH_TARGET:~/scripts/"
    vm_ssh -n -o ConnectTimeout=10 -- 'chmod +x "$HOME/scripts/system-service.sh"'
}

guest_call() {
    local remote='"$HOME/scripts/system-service.sh"' arg
    for arg in "$@"; do
        remote+=" $(printf '%q' "$arg")"
    done
    vm_ssh -o BatchMode=yes -o ConnectTimeout=10 -- "$remote"
}

build_services_json() {
    local json='[]' name port host_port guest_port mode url_lan

    while IFS=$'\t' read -r name port; do
        [[ -n "$name" && -n "$port" ]] || continue
        host_port="${port%%:*}"
        guest_port="${port#*:}"
        mode=$(service_effective_lan "$name")
        url_lan=""
        if [[ "$mode" != "local" ]]; then
            url_lan="http://$(host_local_name):${host_port}"
        fi

        json=$(jq -c \
            --arg name "$name" \
            --arg port "$port" \
            --arg host_port "$host_port" \
            --arg guest_port "$guest_port" \
            --arg mode "$mode" \
            --arg url_lan "$url_lan" \
            '. + [{
                name: $name,
                port: $port,
                host_port: $host_port,
                guest_port: $guest_port,
                lan: $mode,
                url_local: ("http://localhost:" + $host_port),
                url_lan: (if $url_lan == "" then null else $url_lan end)
            }]' <<< "$json")
    done < <(services_entries)

    printf '%s\n' "$json"
}

enrich_units() {
    local units="$1" services="$2" details="$3"

    jq -n --argjson units "$units" --argjson services "$services" --argjson details "$details" '
        [ $units[] |
          . as $u |
          ([ $services[] | select(.guest_port == ($u.port // "") or .name == ($u.service // "")) ] | first) as $s |
          ($u.guest_url // "" | sub("^https?://[^/]+"; "")) as $suffix |
          {
            id: $u.id,
            unit: $u.unit,
            label: $u.label,
            kind: $u.kind,
            state: $u.state,
            sub_state: $u.sub_state,
            enabled: $u.enabled,
            since: $u.since,
            port: ($u.port // ($s.guest_port // null)),
            service_name: ($s.name // null),
            exposed: ($s != null),
            url_local: (if $s == null then null
                        elif $details then ($s.url_local + $suffix)
                        else $s.url_local end),
            url_lan: (if $s == null or $s.url_lan == null then null
                      elif $details then ($s.url_lan + $suffix)
                      else $s.url_lan end),
            password: (if $details then ($u.password // null) else null end),
            guest_url: (if $details then ($u.guest_url // null) else null end),
            has_secret: (($u.password // "") != "" or (($u.guest_url // "") | test("[?&]token=")))
          }
        ]'
}

print_list() {
    local units="$1"
    local count
    count=$(printf '%s' "$units" | jq 'length')

    if [[ "$count" == "0" ]]; then
        echo "No system service installed."
        return 0
    fi

    printf '  %-16s %-9s %-12s %s\n' "SERVICE" "STATE" "ENABLED" "UNIT"
    printf '%s' "$units" | jq -r '
        .[] | [.label, .state, (.enabled // ""), .unit] | @tsv
    ' | while IFS=$'\t' read -r label state enabled unit; do
        printf '  %-16s %-9s %-12s %s\n' "$label" "$state" "$enabled" "$unit"
    done
}

print_info() {
    local unit="$1"

    printf 'Service:  %s\n' "$(printf '%s' "$unit" | jq -r '.label')"
    printf 'Unit:     %s\n' "$(printf '%s' "$unit" | jq -r '.unit')"
    printf 'State:    %s' "$(printf '%s' "$unit" | jq -r '.state')"
    local sub
    sub=$(printf '%s' "$unit" | jq -r '.sub_state // empty')
    [[ -n "$sub" ]] && printf ' (%s)' "$sub"
    printf '\n'
    printf 'Enabled:  %s\n' "$(printf '%s' "$unit" | jq -r '.enabled // "—"')"

    local since
    since=$(printf '%s' "$unit" | jq -r '.since // empty')
    if [[ -n "$since" ]]; then
        printf 'Since:    %s\n' "$(date -d "@$since" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || printf '%s' "$since")"
    fi

    local url_local url_lan password guest_url
    url_local=$(printf '%s' "$unit" | jq -r '.url_local // empty')
    url_lan=$(printf '%s' "$unit" | jq -r '.url_lan // empty')
    password=$(printf '%s' "$unit" | jq -r '.password // empty')
    guest_url=$(printf '%s' "$unit" | jq -r '.guest_url // empty')

    [[ -n "$url_local" ]] && printf 'localhost: %s\n' "$url_local"
    [[ -n "$url_lan" ]] && printf 'LAN:       %s\n' "$url_lan"
    [[ -n "$password" ]] && printf 'Password:  %s\n' "$password"
    if [[ -z "$url_local" && -n "$guest_url" ]]; then
        printf 'In VM:     %s\n' "$guest_url"
    fi
}

ensure_guest_script

case "$ACTION" in
    list)
        UNITS=$(guest_call list)
        SERVICES=$(build_services_json)
        ENRICHED=$(enrich_units "$UNITS" "$SERVICES" false)
        if [[ "$JSON_MODE" == "true" ]]; then
            printf '%s\n' "$ENRICHED"
        else
            print_list "$ENRICHED"
        fi
        ;;
    info)
        UNIT_JSON=$(guest_call info "$NAME")
        if [[ -z "$UNIT_JSON" || "$UNIT_JSON" == "null" ]]; then
            echo "unit not found: $NAME" >&2
            exit 1
        fi
        SERVICES=$(build_services_json)
        ENRICHED=$(enrich_units "[$UNIT_JSON]" "$SERVICES" true | jq '.[0]')
        if [[ "$JSON_MODE" == "true" ]]; then
            printf '%s\n' "$ENRICHED"
        else
            print_info "$ENRICHED"
        fi
        ;;
    logs)
        guest_call logs "$NAME" "$LOG_LINES"
        ;;
    restart)
        guest_call restart "$NAME"
        ;;
esac
