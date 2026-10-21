#!/bin/bash
# Background job wrapper for the AIBox web UI.
#
# Usage: run-job.sh <job_dir> <command> [args...]
# The caller has already created <job_dir> and the global jobs lock.

set -u

job_dir="$1"
shift

jobs_dir="$(cd "$job_dir/.." && pwd)"
lock_dir="$jobs_dir/.lock"
child=""

if [[ -f "$job_dir/secret" ]]; then
    export AIBOX_SUDO_PASSWORD_FILE="$job_dir/secret"
fi

cleanup_secret() {
    rm -f "$job_dir/secret"
}

finish() {
    local rc="$1"
    printf '%s\n' "$rc" > "$job_dir/exit"
    printf 'done\n' > "$job_dir/state"
    date +%s > "$job_dir/finished"
    cleanup_secret
    rm -rf "$lock_dir"
}

cancel() {
    if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
        kill -TERM "$child" 2>/dev/null || true
    fi
    printf 'cancelled\n' > "$job_dir/state"
    printf '143\n' > "$job_dir/exit"
    date +%s > "$job_dir/finished"
    cleanup_secret
    rm -rf "$lock_dir"
    exit 143
}

trap cancel TERM INT HUP

echo $$ > "$job_dir/pid"
printf 'running\n' > "$job_dir/state"

"$@" >> "$job_dir/log" 2>&1 &
child=$!
printf '%s\n' "$child" > "$job_dir/child"

wait "$child"
rc=$?
finish "$rc"
