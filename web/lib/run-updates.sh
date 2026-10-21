#!/bin/bash
# Sequential update runner for the web UI.
#
# Usage: run-updates.sh <aibox> <target>...
# The web job runner may feed the guest sudo password on stdin. It is kept in
# memory and piped to the OS update command only.

set -u

aibox_bin="$1"
shift

sudo_password=""
if [[ "${AIBOX_WEB_JOB:-0}" == "1" ]]; then
    IFS= read -r sudo_password || true
fi

rc=0
for target in "$@"; do
    echo ""
    echo "=== Update: $target ==="

    args=(update "$target")
    if [[ "$target" == "os" ]]; then
        args+=(-y)
    fi

    if [[ "$target" == "os" && -n "$sudo_password" ]]; then
        printf '%s\n' "$sudo_password" | "$aibox_bin" "${args[@]}"
    else
        "$aibox_bin" "${args[@]}"
    fi

    status=$?
    if (( status != 0 )); then
        echo "Update failed: $target" >&2
        rc=1
        break
    fi
done

exit "$rc"
