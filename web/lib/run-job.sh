#!/bin/bash
# Background job wrapper for the AIBox web UI.
#
# Usage: run-job.sh <secret|nosecret> <job_dir> <command> [args...]
# With 'secret', the first line of stdin is the guest sudo password. It is
# kept in a shell variable and piped to the command's stdin; it is never
# exported, written to a file, or included in the command line.

set -u

mode="$1"
shift
job_dir="$1"
shift

jobs_dir="$(cd "$job_dir/.." && pwd)"
lock_dir="$jobs_dir/.lock"
child=""
sudo_password=""

export AIBOX_WEB_JOB=1

if [[ "$mode" == "secret" ]]; then
    IFS= read -r sudo_password || true
fi

finish() {
    local rc="$1"
    printf '%s\n' "$rc" > "$job_dir/exit"
    printf 'done\n' > "$job_dir/state"
    date +%s > "$job_dir/finished"
    rm -rf "$lock_dir"
}

cancel() {
    if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
        kill -TERM "$child" 2>/dev/null || true
    fi
    printf 'cancelled\n' > "$job_dir/state"
    printf '143\n' > "$job_dir/exit"
    date +%s > "$job_dir/finished"
    rm -rf "$lock_dir"
    exit 143
}

trap cancel TERM INT HUP

echo $$ > "$job_dir/pid"
printf 'running\n' > "$job_dir/state"

if [[ -n "$sudo_password" ]]; then
    printf '%s\n' "$sudo_password" | "$@" >> "$job_dir/log" 2>&1 &
else
    "$@" >> "$job_dir/log" 2>&1 < /dev/null &
fi
child=$!
printf '%s\n' "$child" > "$job_dir/child"

wait "$child"
rc=$?
finish "$rc"
