#!/bin/bash
# Inspect and manage the services installed inside the VM.
#
# Usage:
#   system-service.sh list
#   system-service.sh info <id>
#   system-service.sh logs <id> [lines]
#   system-service.sh restart <id>
#
# IDs: opencode (opencode.service), dsh-web (dsh-web.service),
#      vscode-server (Docker container).
# Internal guest helper for web/lib/system-service.sh.

set -u

usage() {
    echo "Usage: $0 <list|info|logs|restart> [id] [options]"
    echo ""
    echo "IDs: opencode, dsh-web, vscode-server"
}

unit_spec() {
    case "$1" in
        opencode)
            UNIT_ID="opencode"
            UNIT_NAME="opencode.service"
            UNIT_KIND="systemd"
            UNIT_SERVICE="opencode"
            UNIT_LABEL="opencode"
            ;;
        dsh-web)
            UNIT_ID="dsh-web"
            UNIT_NAME="dsh-web.service"
            UNIT_KIND="systemd"
            UNIT_SERVICE="dsh"
            UNIT_LABEL="dsh-web"
            ;;
        vscode-server)
            UNIT_ID="vscode-server"
            UNIT_NAME="vscode-server"
            UNIT_KIND="docker"
            UNIT_SERVICE="vscode-server"
            UNIT_LABEL="vscode-server"
            ;;
        *)
            return 1
            ;;
    esac
}

systemd_installed() {
    systemctl --user cat "$1" >/dev/null 2>&1
}

systemd_state() {
    case "$1" in
        active) printf 'running\n' ;;
        inactive) printf 'stopped\n' ;;
        failed) printf 'failed\n' ;;
        activating) printf 'starting\n' ;;
        deactivating) printf 'stopping\n' ;;
        reloading|refreshing) printf 'running\n' ;;
        "") printf 'unknown\n' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

epoch_or_empty() {
    local value="$1" epoch
    [[ -n "$value" ]] || return 0
    epoch=$(date -d "$value" +%s 2>/dev/null) || return 0
    printf '%s\n' "$epoch"
}

systemd_journal() {
    local unit="$1" since
    since=$(systemctl --user show -p ActiveEnterTimestamp --value "$unit" 2>/dev/null)
    if [[ -n "$since" ]]; then
        journalctl --user -u "$unit" --since "$since" --no-pager -o cat 2>/dev/null
    else
        journalctl --user -u "$unit" -n 500 --no-pager -o cat 2>/dev/null
    fi
}

last_url() {
    local unit="$1" filter="${2:-}"
    systemd_journal "$unit" \
        | tr -d '\033' \
        | grep -E "$filter" \
        | grep -oE 'https?://[^[:space:]"]+' \
        | tail -n 1
}

last_password() {
    local unit="$1"
    systemd_journal "$unit" \
        | tr -d '\033' \
        | sed -nE 's/.*server password ([^[:space:]]+).*/\1/p' \
        | tail -n 1
}

url_port() {
    printf '%s' "$1" | sed -nE 's#^https?://[^:/]+:([0-9]+).*#\1#p'
}

url_token() {
    printf '%s' "$1" | sed -nE 's/.*[?&]token=([^&]+).*/\1/p'
}

docker_installed() {
    command -v docker >/dev/null 2>&1 || return 1
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'vscode-server'
}

docker_state() {
    case "$1" in
        true) printf 'running\n' ;;
        *) printf 'stopped\n' ;;
    esac
}

vscode_password() {
    local compose="$HOME/vscode-server/docker-compose.yml"
    [[ -f "$compose" ]] || return 0
    sed -nE 's/^[[:space:]]*-[[:space:]]*"?PASSWORD=([^"]*)"?[[:space:]]*$/\1/p' "$compose" | head -n 1
}

emit_systemd() {
    local id="$1" unit="$2" service="$3" label="$4" details="$5"
    systemd_installed "$unit" || return 0

    local active sub enabled since state port="" url="" password=""
    active=$(systemctl --user show -p ActiveState --value "$unit" 2>/dev/null)
    sub=$(systemctl --user show -p SubState --value "$unit" 2>/dev/null)
    enabled=$(systemctl --user show -p UnitFileState --value "$unit" 2>/dev/null)
    state=$(systemd_state "$active")
    if [[ "$state" == "running" ]]; then
        since=$(epoch_or_empty "$(systemctl --user show -p ActiveEnterTimestamp --value "$unit" 2>/dev/null)")
    else
        since=""
    fi

    if [[ "$details" == "true" && "$state" == "running" ]]; then
        case "$id" in
            opencode)
                url=$(last_url "$unit" 'server listening')
                password=$(last_password "$unit")
                ;;
            dsh-web)
                url=$(last_url "$unit")
                password=$(url_token "$url")
                ;;
        esac
        port=$(url_port "$url")
    fi

    jq -n \
        --arg id "$id" \
        --arg unit "$unit" \
        --arg label "$label" \
        --arg kind "systemd" \
        --arg service "$service" \
        --arg state "$state" \
        --arg sub_state "$sub" \
        --arg enabled "$enabled" \
        --arg since "$since" \
        --arg port "$port" \
        --arg guest_url "$url" \
        --arg password "$password" \
        '{
            id: $id,
            unit: $unit,
            label: $label,
            kind: $kind,
            service: $service,
            installed: true,
            state: $state,
            sub_state: $sub_state,
            enabled: $enabled,
            since: (if $since == "" then null else ($since | tonumber) end),
            port: (if $port == "" then null else $port end),
            guest_url: (if $guest_url == "" then null else $guest_url end),
            password: (if $password == "" then null else $password end)
        }'
}

emit_docker() {
    local details="$1"
    docker_installed || return 0

    local running state enabled since="" port="" url="" password="" sub_state
    running=$(docker inspect -f '{{.State.Running}}' vscode-server 2>/dev/null || echo false)
    state=$(docker_state "$running")
    if [[ "$running" == "true" ]]; then
        sub_state="running"
    else
        sub_state="exited"
    fi
    enabled=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' vscode-server 2>/dev/null || true)

    if [[ "$state" == "running" ]]; then
        since=$(epoch_or_empty "$(docker inspect -f '{{.State.StartedAt}}' vscode-server 2>/dev/null)")
        port=$(docker port vscode-server 8080/tcp 2>/dev/null | head -n 1 | sed 's/.*://')
        password=$(vscode_password)
        [[ -n "$port" ]] && url="http://127.0.0.1:${port}"
    fi

    if [[ "$details" != "true" ]]; then
        url=""
        password=""
    fi

    jq -n \
        --arg id "vscode-server" \
        --arg unit "vscode-server" \
        --arg label "vscode-server" \
        --arg kind "docker" \
        --arg service "vscode-server" \
        --arg state "$state" \
        --arg sub_state "$sub_state" \
        --arg enabled "$enabled" \
        --arg since "$since" \
        --arg port "$port" \
        --arg guest_url "$url" \
        --arg password "$password" \
        '{
            id: $id,
            unit: $unit,
            label: $label,
            kind: $kind,
            service: $service,
            installed: true,
            state: $state,
            sub_state: $sub_state,
            enabled: $enabled,
            since: (if $since == "" then null else ($since | tonumber) end),
            port: (if $port == "" then null else $port end),
            guest_url: (if $guest_url == "" then null else $guest_url end),
            password: (if $password == "" then null else $password end)
        }'
}

do_list() {
    local tmp
    tmp=$(mktemp) || exit 1
    {
        emit_systemd opencode opencode.service opencode opencode false
        emit_systemd dsh-web dsh-web.service dsh dsh-web false
        emit_docker false
    } >> "$tmp"
    jq -s '.' "$tmp"
    rm -f "$tmp"
}

do_info() {
    local id="$1"
    unit_spec "$id" || {
        echo "Unknown unit: $id" >&2
        exit 1
    }

    case "$UNIT_KIND" in
        systemd)
            if ! systemd_installed "$UNIT_NAME"; then
                echo "Unit not installed: $UNIT_NAME" >&2
                exit 1
            fi
            emit_systemd "$UNIT_ID" "$UNIT_NAME" "$UNIT_SERVICE" "$UNIT_LABEL" true
            ;;
        docker)
            if ! docker_installed; then
                echo "Unit not installed: vscode-server" >&2
                exit 1
            fi
            emit_docker true
            ;;
    esac
}

do_logs() {
    local id="$1" lines="${2:-200}"
    unit_spec "$id" || {
        echo "Unknown unit: $id" >&2
        exit 1
    }

    [[ "$lines" =~ ^[0-9]+$ ]] || lines=200
    (( lines > 2000 )) && lines=2000

    case "$UNIT_KIND" in
        systemd)
            systemd_installed "$UNIT_NAME" || {
                echo "Unit not installed: $UNIT_NAME" >&2
                exit 1
            }
            journalctl --user -u "$UNIT_NAME" -n "$lines" --no-pager -o cat 2>&1 || true
            ;;
        docker)
            docker_installed || {
                echo "Unit not installed: vscode-server" >&2
                exit 1
            }
            docker logs --tail "$lines" vscode-server 2>&1 || true
            ;;
    esac
}

do_restart() {
    local id="$1"
    unit_spec "$id" || {
        echo "Unknown unit: $id" >&2
        exit 1
    }

    case "$UNIT_KIND" in
        systemd)
            systemd_installed "$UNIT_NAME" || {
                echo "Unit not installed: $UNIT_NAME" >&2
                exit 1
            }
            systemctl --user restart "$UNIT_NAME"
            sleep 1
            echo "$UNIT_NAME restarted ($(systemctl --user is-active "$UNIT_NAME" 2>/dev/null || true))"
            ;;
        docker)
            docker_installed || {
                echo "Unit not installed: vscode-server" >&2
                exit 1
            }
            if [[ -f "$HOME/vscode-server/docker-compose.yml" ]]; then
                (cd "$HOME/vscode-server" && docker compose restart vscode-server)
            else
                docker restart vscode-server
            fi
            ;;
    esac
}

ACTION="${1:-list}"
shift || true

case "$ACTION" in
    list|--json)
        do_list
        ;;
    info)
        [[ $# -ge 1 ]] || { usage >&2; exit 1; }
        do_info "$1"
        ;;
    logs)
        [[ $# -ge 1 ]] || { usage >&2; exit 1; }
        do_logs "$1" "${2:-200}"
        ;;
    restart)
        [[ $# -ge 1 ]] || { usage >&2; exit 1; }
        do_restart "$1"
        ;;
    -h|--help)
        usage
        ;;
    *)
        echo "Unknown action: $ACTION" >&2
        usage >&2
        exit 1
        ;;
esac
