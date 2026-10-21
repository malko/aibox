#!/bin/bash
# Cancel all running jobs. Used by the delayed quit triggered when the web
# page is closed. It intentionally has no HTTP output.

jobs_dir="${AIBOX_WEB_JOBS_DIR:-${XDG_RUNTIME_DIR:-$HOME/.cache}/aibox-web/jobs}"
[[ -d "$jobs_dir" ]] || exit 0

kill_process_tree() {
    local pid="$1" child
    [[ -n "$pid" ]] || return 0
    for child in $(pgrep -P "$pid" 2>/dev/null); do
        kill_process_tree "$child"
    done
    kill -TERM "$pid" 2>/dev/null || true
}

for dir in "$jobs_dir"/*; do
    [[ -d "$dir" ]] || continue
    [[ "$(cat "$dir/state" 2>/dev/null || true)" == "running" ]] || continue

    child=$(cat "$dir/child" 2>/dev/null || true)
    if [[ -n "$child" ]]; then
        kill_process_tree "$child"
    fi

    pid=$(cat "$dir/pid" 2>/dev/null || true)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
    fi

    printf 'cancelled\n' > "$dir/state"
    printf '143\n' > "$dir/exit"
    date +%s > "$dir/finished"
done

rm -rf "$jobs_dir/.lock"
