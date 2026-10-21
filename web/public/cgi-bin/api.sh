#!/bin/bash
# AIBox web API (BusyBox CGI).
#
# All routes are local-only and token-protected. Actions that take more than a
# few seconds are started as background jobs; the browser polls /job?id=...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/cgi-lib.sh"

METHOD="${REQUEST_METHOD:-GET}"
ROUTE="${PATH_INFO:-/}"
ROUTE="${ROUTE#/}"

query_get() {
    local key="$1" part
    local IFS='&'
    for part in ${QUERY_STRING:-}; do
        case "$part" in
            "$key="*) printf '%s' "${part#*=}"; return 0 ;;
        esac
    done
    return 1
}

api_action() {
    local output error_file rc
    error_file=$(mktemp) || return 1

    output=$("$AIBOX_BIN" "$@" 2>"$error_file")
    rc=$?

    if (( rc != 0 )); then
        local error
        error=$(cat "$error_file")
        rm -f "$error_file"
        json_error "500 Internal Server Error" "${error:-aibox command failed}"
        return 1
    fi

    rm -f "$error_file"
    json_response "$(jq -n --arg output "$output" '{ok:true,output:$output}')"
}

cgi_require_auth || exit 0

case "$METHOD $ROUTE" in
    "GET status")
        cgi_aibox_json status --json || exit 0
        ;;

    "GET services")
        cgi_aibox_json service-list --json || exit 0
        ;;

    "GET updates")
        cgi_aibox_json check-updates --cached --json || exit 0
        ;;

    "GET setup")
        cgi_aibox_json setup --status --json || exit 0
        ;;

    "GET service-url")
        NAME=$(query_get name || true)
        if [[ -z "$NAME" ]] || ! validate_service_name "$NAME"; then
            json_error "400 Bad Request" "invalid service name"
            exit 0
        fi

        error_file=$(mktemp)
        if ! output=$("$AIBOX_BIN" tunnel status --json --tokens 2>"$error_file"); then
            error=$(cat "$error_file")
            rm -f "$error_file"
            json_error "500 Internal Server Error" "${error:-could not resolve service URL}"
            exit 0
        fi
        rm -f "$error_file"

        item=$(printf '%s' "$output" | jq -c --arg name "$NAME" '.services[] | select(.name == $name)')
        if [[ -z "$item" ]]; then
            json_error "404 Not Found" "service not found"
            exit 0
        fi
        json_response "$item"
        ;;

    "POST services/add")
        cgi_json_body || exit 0
        NAME=$(printf '%s' "$CGI_BODY" | jq -r '.name // empty')
        PORT=$(printf '%s' "$CGI_BODY" | jq -r '.port // empty')
        LAN=$(printf '%s' "$CGI_BODY" | jq -r '.lan // "local"')
        TIMEOUT=$(printf '%s' "$CGI_BODY" | jq -r '.timeout // "2h"')

        if ! validate_service_name "$NAME"; then
            json_error "400 Bad Request" "invalid service name"
            exit 0
        fi
        if ! validate_port "$PORT"; then
            json_error "400 Bad Request" "invalid port"
            exit 0
        fi
        if [[ "$LAN" != "local" && "$LAN" != "permanent" && "$LAN" != "temporary" ]]; then
            json_error "400 Bad Request" "invalid LAN mode"
            exit 0
        fi
        if [[ "$LAN" == "temporary" ]] && ! validate_timeout "$TIMEOUT"; then
            json_error "400 Bad Request" "invalid timeout"
            exit 0
        fi

        error_file=$(mktemp)
        if [[ "$LAN" == "permanent" ]]; then
            output=$("$AIBOX_BIN" service-add "$NAME" "$PORT" --lan --yes 2>"$error_file")
        else
            output=$("$AIBOX_BIN" service-add "$NAME" "$PORT" 2>"$error_file")
        fi
        rc=$?
        if (( rc == 0 )) && [[ "$LAN" == "temporary" ]]; then
            output="$output
$("$AIBOX_BIN" tunnel lan on "$NAME" --timeout "$TIMEOUT" --yes 2>>"$error_file")"
            rc=$?
        fi

        if (( rc != 0 )); then
            error=$(cat "$error_file")
            rm -f "$error_file"
            json_error "500 Internal Server Error" "${error:-could not add service}"
            exit 0
        fi
        rm -f "$error_file"
        json_response "$(jq -n --arg output "$output" '{ok:true,output:$output}')"
        ;;

    "POST services/update")
        cgi_json_body || exit 0
        NAME=$(printf '%s' "$CGI_BODY" | jq -r '.name // empty')
        NEW_NAME=$(printf '%s' "$CGI_BODY" | jq -r '.new_name // empty')
        PORT=$(printf '%s' "$CGI_BODY" | jq -r '.port // empty')
        LAN=$(printf '%s' "$CGI_BODY" | jq -r '.lan // "keep"')
        TIMEOUT=$(printf '%s' "$CGI_BODY" | jq -r '.timeout // "2h"')

        if ! validate_service_name "$NAME"; then
            json_error "400 Bad Request" "invalid service name"
            exit 0
        fi
        if [[ -n "$NEW_NAME" ]] && ! validate_service_name "$NEW_NAME"; then
            json_error "400 Bad Request" "invalid new service name"
            exit 0
        fi
        if [[ -n "$PORT" ]] && ! validate_port "$PORT"; then
            json_error "400 Bad Request" "invalid port"
            exit 0
        fi
        if [[ "$LAN" != "keep" && "$LAN" != "local" && "$LAN" != "permanent" && "$LAN" != "temporary" ]]; then
            json_error "400 Bad Request" "invalid LAN mode"
            exit 0
        fi
        if [[ "$LAN" == "temporary" ]] && ! validate_timeout "$TIMEOUT"; then
            json_error "400 Bad Request" "invalid timeout"
            exit 0
        fi

        args=(service-edit "$NAME")
        [[ -n "$NEW_NAME" && "$NEW_NAME" != "$NAME" ]] && args+=(--name "$NEW_NAME")
        [[ -n "$PORT" ]] && args+=(--port "$PORT")
        [[ "$LAN" == "permanent" ]] && args+=(--lan)
        [[ "$LAN" == "local" || "$LAN" == "temporary" ]] && args+=(--local)

        error_file=$(mktemp)
        output=$("$AIBOX_BIN" "${args[@]}" 2>"$error_file")
        rc=$?

        target_name="${NEW_NAME:-$NAME}"
        if (( rc == 0 )) && [[ "$LAN" == "temporary" ]]; then
            output="$output
$("$AIBOX_BIN" tunnel lan on "$target_name" --timeout "$TIMEOUT" --yes 2>>"$error_file")"
            rc=$?
        fi

        if (( rc != 0 )); then
            error=$(cat "$error_file")
            rm -f "$error_file"
            json_error "500 Internal Server Error" "${error:-could not update service}"
            exit 0
        fi
        rm -f "$error_file"
        json_response "$(jq -n --arg output "$output" '{ok:true,output:$output}')"
        ;;

    "POST services/remove")
        cgi_json_body || exit 0
        NAME=$(printf '%s' "$CGI_BODY" | jq -r '.name // empty')
        if ! validate_service_name "$NAME"; then
            json_error "400 Bad Request" "invalid service name"
            exit 0
        fi
        api_action service-remove "$NAME" || exit 0
        ;;

    "POST lan")
        cgi_json_body || exit 0
        NAME=$(printf '%s' "$CGI_BODY" | jq -r '.name // empty')
        MODE=$(printf '%s' "$CGI_BODY" | jq -r '.mode // empty')
        TIMEOUT=$(printf '%s' "$CGI_BODY" | jq -r '.timeout // "2h"')

        if ! validate_service_name "$NAME"; then
            json_error "400 Bad Request" "invalid service name"
            exit 0
        fi
        case "$MODE" in
            local) api_action tunnel lan off "$NAME" || exit 0 ;;
            permanent) api_action tunnel lan on "$NAME" --permanent --yes || exit 0 ;;
            temporary)
                if ! validate_timeout "$TIMEOUT"; then
                    json_error "400 Bad Request" "invalid timeout"
                    exit 0
                fi
                api_action tunnel lan on "$NAME" --timeout "$TIMEOUT" --yes || exit 0
                ;;
            *)
                json_error "400 Bad Request" "invalid LAN mode"
                exit 0
                ;;
        esac
        ;;

    "POST vm")
        cgi_json_body || exit 0
        ACTION=$(printf '%s' "$CGI_BODY" | jq -r '.action // empty')
        FORCE=$(printf '%s' "$CGI_BODY" | jq -r '.force // false')

        case "$ACTION" in
            start)
                job_start "Démarrage de la VM" start || exit 0
                ;;
            shutdown)
                if [[ "$FORCE" == "true" ]]; then
                    job_start "Arrêt forcé de la VM" shutdown -f || exit 0
                else
                    job_start "Arrêt de la VM" shutdown || exit 0
                fi
                ;;
            restart)
                if [[ "$FORCE" == "true" ]]; then
                    job_start "Redémarrage forcé de la VM" restart -f || exit 0
                else
                    job_start "Redémarrage de la VM" restart || exit 0
                fi
                ;;
            *)
                json_error "400 Bad Request" "invalid VM action"
                exit 0
                ;;
        esac
        ;;

    "POST tunnel")
        cgi_json_body || exit 0
        ACTION=$(printf '%s' "$CGI_BODY" | jq -r '.action // empty')
        case "$ACTION" in
            start|stop|restart)
                job_start "Tunnel: $ACTION" tunnel "$ACTION" || exit 0
                ;;
            *)
                json_error "400 Bad Request" "invalid tunnel action"
                exit 0
                ;;
        esac
        ;;

    "POST updates/check")
        job_start "Vérification des mises à jour" check-updates || exit 0
        ;;

    "POST updates/apply")
        cgi_json_body || exit 0
        TARGET=$(printf '%s' "$CGI_BODY" | jq -r '.target // empty')
        SUDO_PASSWORD=$(printf '%s' "$CGI_BODY" | jq -r '.sudo_password // empty')

        case "$TARGET" in
            scripts|opencode|opencode-service|dsh|claude|vscode-server)
                job_start "Mise à jour: $TARGET" update "$TARGET" || exit 0
                ;;
            os)
                if [[ -z "$SUDO_PASSWORD" ]]; then
                    json_error "400 Bad Request" "sudo password is required for OS updates"
                    exit 0
                fi
                AIBOX_JOB_PASSWORD="$SUDO_PASSWORD"
                job_start "Mise à jour: OS" update os -y || exit 0
                unset AIBOX_JOB_PASSWORD
                ;;
            all)
                if [[ -z "$SUDO_PASSWORD" ]]; then
                    json_error "400 Bad Request" "sudo password is required for OS updates"
                    exit 0
                fi
                AIBOX_JOB_PASSWORD="$SUDO_PASSWORD"
                job_start "Mise à jour: tout" update all -y || exit 0
                unset AIBOX_JOB_PASSWORD
                ;;
            *)
                json_error "400 Bad Request" "invalid update target"
                exit 0
                ;;
        esac
        ;;

    "POST self-update")
        job_start "Mise à jour de aibox" self-update || exit 0
        ;;

    "POST setup/run")
        cgi_json_body || exit 0
        STEP=$(printf '%s' "$CGI_BODY" | jq -r '.step // empty')
        WITH_DEPS=$(printf '%s' "$CGI_BODY" | jq -r '.with_deps // false')

        if [[ -z "$STEP" || ! "$STEP" =~ ^[a-z][a-z0-9-]*$ ]]; then
            json_error "400 Bad Request" "invalid setup step"
            exit 0
        fi

        error_file=$(mktemp)
        if ! status_json=$("$AIBOX_BIN" setup --status --json 2>"$error_file"); then
            error=$(cat "$error_file")
            rm -f "$error_file"
            json_error "500 Internal Server Error" "${error:-could not read setup status}"
            exit 0
        fi
        rm -f "$error_file"

        runnable=$(printf '%s' "$status_json" | jq -r --arg step "$STEP" \
            '.steps[] | select(.name == $step) | .web_runnable // empty')
        if [[ "$runnable" != "true" ]]; then
            json_error "400 Bad Request" "this setup step is not available from the web UI"
            exit 0
        fi

        vm_running=$(printf '%s' "$status_json" | jq -r '.vm.running // false')
        if [[ "$vm_running" != "true" && "$STEP" != "cli" && "$STEP" != "tunnel" ]]; then
            json_error "400 Bad Request" "the VM must be running for this setup step"
            exit 0
        fi

        args=(setup "$STEP" --yes --no-banner)
        [[ "$WITH_DEPS" != "true" ]] && args+=(--no-deps)
        job_start "Setup: $STEP" "${args[@]}" || exit 0
        ;;

    "GET job")
        ID=$(query_get id || true)
        if [[ -z "$ID" || ! "$ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
            json_error "400 Bad Request" "invalid job id"
            exit 0
        fi
        job_status "$ID" || exit 0
        ;;

    "POST job/cancel")
        cgi_json_body || exit 0
        ID=$(printf '%s' "$CGI_BODY" | jq -r '.id // empty')
        if [[ -z "$ID" || ! "$ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
            json_error "400 Bad Request" "invalid job id"
            exit 0
        fi
        job_cancel "$ID" || exit 0
        ;;

    "POST config")
        cgi_json_body || exit 0
        HOSTNAME=$(printf '%s' "$CGI_BODY" | jq -r '.lan_hostname // empty')
        if ! validate_hostname "$HOSTNAME"; then
            json_error "400 Bad Request" "invalid LAN hostname"
            exit 0
        fi
        api_action config set LAN_HOSTNAME "$HOSTNAME" || exit 0
        ;;

    "POST session")
        cgi_json_body || exit 0
        SESSION_ID=$(printf '%s' "$CGI_BODY" | jq -r '.id // empty')
        if [[ -z "$SESSION_ID" || ! "$SESSION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
            json_error "400 Bad Request" "invalid session id"
            exit 0
        fi
        printf '%s\n' "$SESSION_ID" > "$AIBOX_WEB_SESSION_FILE"
        chmod 600 "$AIBOX_WEB_SESSION_FILE" 2>/dev/null || true
        rm -f "$AIBOX_WEB_QUIT_FLAG"
        json_response '{"ok":true}'
        ;;

    "POST quit/cancel")
        rm -f "$AIBOX_WEB_QUIT_FLAG"
        json_response '{"ok":true}'
        ;;

    "POST quit")
        cgi_json_body || exit 0
        SESSION_ID=$(printf '%s' "$CGI_BODY" | jq -r '.session_id // empty')
        if [[ -n "$SESSION_ID" && ! "$SESSION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
            json_error "400 Bad Request" "invalid session id"
            exit 0
        fi

        CURRENT_SESSION=$(cat "$AIBOX_WEB_SESSION_FILE" 2>/dev/null || true)
        if [[ -n "$SESSION_ID" && -n "$CURRENT_SESSION" && "$SESSION_ID" != "$CURRENT_SESSION" ]]; then
            json_response '{"ok":true,"ignored":true}'
            exit 0
        fi

        PID_FILE="${AIBOX_WEB_PID_FILE:-}"
        if [[ -z "$PID_FILE" || ! -f "$PID_FILE" ]]; then
            json_error "500 Internal Server Error" "web PID file not found"
            exit 0
        fi
        PID=$(cat "$PID_FILE")
        if [[ ! "$PID" =~ ^[0-9]+$ ]]; then
            json_error "500 Internal Server Error" "invalid web PID"
            exit 0
        fi

        DELAY=$(query_get delay || true)
        if [[ -n "$DELAY" ]]; then
            if [[ ! "$DELAY" =~ ^[0-9]+$ ]] || (( DELAY < 0 || DELAY > 30 )); then
                json_error "400 Bad Request" "invalid quit delay"
                exit 0
            fi

            QUIT_ID="$(date +%s)-$$-$RANDOM"
            printf '%s|%s|%s\n' "$QUIT_ID" "$SESSION_ID" "$(date +%s)" > "$AIBOX_WEB_QUIT_FLAG"
            chmod 600 "$AIBOX_WEB_QUIT_FLAG" 2>/dev/null || true

            json_response '{"ok":true,"delayed":true}'
            nohup bash -c '
                sleep "$1"
                if [ -f "$2" ]; then
                    IFS="|" read -r id sid started < "$2"
                    if [ "$id" = "$3" ]; then
                        if [ -z "$4" ] || [ "$(cat "$5" 2>/dev/null || true)" = "$4" ]; then
                            "$6" >/dev/null 2>&1 || true
                            kill -TERM "$7" 2>/dev/null || true
                        fi
                        rm -f "$2"
                    fi
                fi
            ' _ "$DELAY" "$AIBOX_WEB_QUIT_FLAG" "$QUIT_ID" "$SESSION_ID" "$AIBOX_WEB_SESSION_FILE" \
                "$AIBOX_ROOT/web/lib/cancel-jobs.sh" "$PID" >/dev/null 2>&1 &
            exit 0
        fi

        rm -f "$AIBOX_WEB_QUIT_FLAG"
        job_cancel_all
        json_response '{"ok":true}'
        nohup bash -c "sleep 1; kill -TERM $PID 2>/dev/null || true" >/dev/null 2>&1 &
        ;;

    *)
        json_error "404 Not Found" "unknown route"
        ;;
esac
