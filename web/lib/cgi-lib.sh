#!/bin/bash
# Shared helpers for the AIBox BusyBox CGI API.
#
# The web UI is local-only. Every API request needs the token written by
# 'aibox web' and sent as "Authorization: Bearer <token>". Mutating requests
# are also checked against the Host/Origin headers to block DNS rebinding and
# cross-site form posts.

AIBOX_ROOT="${AIBOX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
AIBOX_BIN="$AIBOX_ROOT/aibox"
AIBOX_WEB_PORT="${AIBOX_WEB_PORT:-8787}"
AIBOX_WEB_TOKEN_FILE="${AIBOX_WEB_TOKEN_FILE:-$HOME/.config/aibox/web-token}"
AIBOX_WEB_JOBS_DIR="${AIBOX_WEB_JOBS_DIR:-${XDG_RUNTIME_DIR:-$HOME/.cache}/aibox-web/jobs}"
AIBOX_WEB_QUIT_FLAG="${AIBOX_WEB_QUIT_FLAG:-${XDG_RUNTIME_DIR:-$HOME/.cache}/aibox-web.quit}"
AIBOX_WEB_SESSION_FILE="${AIBOX_WEB_SESSION_FILE:-${XDG_RUNTIME_DIR:-$HOME/.cache}/aibox-web.session}"

umask 077

json_response() {
    printf 'Content-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n%s\n' "$1"
}

json_error() {
    local status="$1" message="$2"
    printf 'Status: %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n%s\n' \
        "$status" "$(jq -n --arg error "$message" '{ok:false,error:$error}')"
}

cgi_require_auth() {
    local expected provided host origin

    expected=$(cat "$AIBOX_WEB_TOKEN_FILE" 2>/dev/null || true)
    if [[ -z "$expected" ]]; then
        json_error "500 Internal Server Error" "web token is missing; restart aibox web"
        return 1
    fi

    provided="${HTTP_AUTHORIZATION:-}"
    provided="${provided#Bearer }"
    if [[ -z "$provided" || "$provided" != "$expected" ]]; then
        json_error "401 Unauthorized" "invalid or missing token"
        return 1
    fi

    host="${HTTP_HOST:-}"
    case "$host" in
        "127.0.0.1:$AIBOX_WEB_PORT"|"localhost:$AIBOX_WEB_PORT") ;;
        *)
            json_error "403 Forbidden" "invalid Host header"
            return 1
            ;;
    esac

    origin="${HTTP_ORIGIN:-}"
    if [[ -n "$origin" ]]; then
        case "$origin" in
            "http://127.0.0.1:$AIBOX_WEB_PORT"|"http://localhost:$AIBOX_WEB_PORT") ;;
            *)
                json_error "403 Forbidden" "invalid Origin header"
                return 1
                ;;
        esac
    fi

    return 0
}

cgi_require_method() {
    local expected="$1"
    if [[ "${REQUEST_METHOD:-}" != "$expected" ]]; then
        json_error "405 Method Not Allowed" "expected $expected"
        return 1
    fi
    return 0
}

cgi_read_body() {
    local length="${CONTENT_LENGTH:-0}"

    if [[ ! "$length" =~ ^[0-9]+$ ]]; then
        json_error "400 Bad Request" "invalid Content-Length"
        return 1
    fi
    if (( length > 65536 )); then
        json_error "413 Payload Too Large" "request body is too large"
        return 1
    fi

    if (( length > 0 )); then
        cat
    fi
}

CGI_BODY=""

cgi_json_body() {
    local body length="${CONTENT_LENGTH:-0}"

    if [[ ! "$length" =~ ^[0-9]+$ ]]; then
        json_error "400 Bad Request" "invalid Content-Length"
        return 1
    fi
    if (( length > 65536 )); then
        json_error "413 Payload Too Large" "request body is too large"
        return 1
    fi

    if (( length > 0 )); then
        body=$(cat)
    else
        body="{}"
    fi

    if [[ -z "$body" ]]; then
        body="{}"
    fi

    if ! printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
        json_error "400 Bad Request" "invalid JSON body"
        return 1
    fi

    # shellcheck disable=SC2034  # consumed by the API router
    CGI_BODY="$body"
    return 0
}

cgi_aibox_json() {
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
    json_response "$output"
}

cgi_aibox_action() {
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

validate_service_name() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

validate_port() {
    [[ "$1" =~ ^[0-9]+(:[0-9]+)?$ ]]
}

validate_timeout() {
    [[ "$1" =~ ^[0-9]+[smh]?$ ]]
}

validate_snapshot_name() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

validate_hostname() {
    local value="$1"
    [[ -z "$value" ]] && return 0
    [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

# --- Jobs ------------------------------------------------------------------

job_dir_for() {
    printf '%s/%s\n' "$AIBOX_WEB_JOBS_DIR" "$1"
}

job_lock_is_stale() {
    local lock_dir="$AIBOX_WEB_JOBS_DIR/.lock"
    local job_id pid

    job_id=$(cat "$lock_dir/job_id" 2>/dev/null || true)
    [[ -n "$job_id" ]] || return 0

    pid=$(cat "$(job_dir_for "$job_id")/pid" 2>/dev/null || true)
    [[ -n "$pid" ]] || return 0
    kill -0 "$pid" 2>/dev/null || return 0
    return 1
}

job_acquire_lock() {
    local lock_dir="$AIBOX_WEB_JOBS_DIR/.lock"
    mkdir -p "$AIBOX_WEB_JOBS_DIR"

    if mkdir "$lock_dir" 2>/dev/null; then
        return 0
    fi

    if job_lock_is_stale; then
        rm -rf "$lock_dir"
        mkdir "$lock_dir" 2>/dev/null && return 0
    fi

    local running_id
    running_id=$(cat "$lock_dir/job_id" 2>/dev/null || true)
    if [[ -n "$running_id" ]]; then
        json_error "409 Conflict" "another operation is running ($running_id)"
    else
        json_error "409 Conflict" "another operation is running"
    fi
    return 1
}

job_start() {
    local title="$1"
    shift

    job_acquire_lock || return 1

    local id job_dir
    id="$(date +%s)-$$-$RANDOM"
    job_dir=$(job_dir_for "$id")
    mkdir -p "$job_dir"

    printf '%s\n' "$id" > "$AIBOX_WEB_JOBS_DIR/.lock/job_id"
    printf '%s\n' "$title" > "$job_dir/title"
    printf '%s\n' "$*" > "$job_dir/command"
    date +%s > "$job_dir/started"

    # Optional stdin secret (the guest sudo password for OS updates).
    # It is piped directly to the job runner and never written to a file, the
    # command line, the job metadata or the log.
    if [[ -n "${AIBOX_JOB_PASSWORD:-}" ]]; then
        printf '%s\n' "$AIBOX_JOB_PASSWORD" | \
            nohup "$AIBOX_ROOT/web/lib/run-job.sh" secret "$job_dir" "$AIBOX_BIN" "$@" \
                >/dev/null 2>&1 &
        unset AIBOX_JOB_PASSWORD
    else
        nohup "$AIBOX_ROOT/web/lib/run-job.sh" nosecret "$job_dir" "$AIBOX_BIN" "$@" \
            >/dev/null 2>&1 < /dev/null &
    fi

    json_response "$(jq -n --arg id "$id" --arg title "$title" '{ok:true,id:$id,title:$title}')"
}

job_status() {
    local id="$1" job_dir state exit_code log_json title started finished pid
    job_dir=$(job_dir_for "$id")

    if [[ ! -d "$job_dir" ]]; then
        json_error "404 Not Found" "job not found"
        return 1
    fi

    state=$(cat "$job_dir/state" 2>/dev/null || echo "unknown")
    exit_code=$(cat "$job_dir/exit" 2>/dev/null || true)
    title=$(cat "$job_dir/title" 2>/dev/null || true)
    started=$(cat "$job_dir/started" 2>/dev/null || true)
    finished=$(cat "$job_dir/finished" 2>/dev/null || true)
    pid=$(cat "$job_dir/pid" 2>/dev/null || true)

    if [[ "$state" == "running" && -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
        state="failed"
        [[ -n "$exit_code" ]] || exit_code="1"
    fi

    log_json=$(tail -n 250 "$job_dir/log" 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))')

    json_response "$(jq -n \
        --arg id "$id" \
        --arg title "$title" \
        --arg state "$state" \
        --arg exit_code "$exit_code" \
        --arg started "$started" \
        --arg finished "$finished" \
        --argjson log "$log_json" \
        '{
            ok: true,
            id: $id,
            title: $title,
            state: $state,
            exit: (if $exit_code == "" then null else ($exit_code | tonumber) end),
            started: (if $started == "" then null else ($started | tonumber) end),
            finished: (if $finished == "" then null else ($finished | tonumber) end),
            log: $log
        }')"
}

job_cancel() {
    local id="$1" job_dir pid child
    job_dir=$(job_dir_for "$id")

    if [[ ! -d "$job_dir" ]]; then
        json_error "404 Not Found" "job not found"
        return 1
    fi

    child=$(cat "$job_dir/child" 2>/dev/null || true)
    if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
        kill -TERM "$child" 2>/dev/null || true
    fi

    pid=$(cat "$job_dir/pid" 2>/dev/null || true)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
    fi

    printf 'cancelled\n' > "$job_dir/state"
    printf '143\n' > "$job_dir/exit"
    date +%s > "$job_dir/finished"
    rm -rf "$AIBOX_WEB_JOBS_DIR/.lock"

    json_response '{"ok":true}'
}

job_cancel_all() {
    local dir pid child state
    [[ -d "$AIBOX_WEB_JOBS_DIR" ]] || return 0

    for dir in "$AIBOX_WEB_JOBS_DIR"/*; do
        [[ -d "$dir" ]] || continue
        state=$(cat "$dir/state" 2>/dev/null || true)
        [[ "$state" == "running" ]] || continue

        child=$(cat "$dir/child" 2>/dev/null || true)
        if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
            kill -TERM "$child" 2>/dev/null || true
        fi

        pid=$(cat "$dir/pid" 2>/dev/null || true)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi

        printf 'cancelled\n' > "$dir/state"
        printf '143\n' > "$dir/exit"
        date +%s > "$dir/finished"
    done
    rm -rf "$AIBOX_WEB_JOBS_DIR/.lock"
}
