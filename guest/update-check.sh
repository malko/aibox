#!/bin/bash
# Gather available updates and cache them for the MOTD.
# Best-effort: run by a oneshot systemd unit and must never fail hard.

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aibox"
CACHE_FILE="$CACHE_DIR/updates"
VSCODE_DIR="${VSCODE_DIR:-$HOME/vscode-server}"

mkdir -p "$CACHE_DIR"

# APT: simulate an upgrade against the cached package lists (no root needed).
APT_COUNT=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)

# Pending reboot?
if [[ -f /var/run/reboot-required ]]; then
    REBOOT=yes
else
    REBOOT=no
fi

# Global npm packages managed by aibox (opencode, dsh).
NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

NPM_OUTDATED=""
if command -v npm >/dev/null 2>&1; then
    NPM_OUTDATED=$(timeout 30 npm outdated -g --parseable 2>/dev/null \
        | awk -F: '/opencode-ai|deepseek-ai\/dsh/ {
              name=$2; sub(/@[^@]*$/, "", name)
              cur=$2; sub(/^.*@/, "", cur)
              latest=$4; sub(/^.*@/, "", latest)
              printf "%s%s %s->%s", sep, name, cur, latest; sep="; "
          }')
fi

# vscode-server: compare the local image digest with the registry.
VSCODE=no
if [[ -f "$VSCODE_DIR/docker-compose.yml" ]] && command -v docker >/dev/null 2>&1; then
    IMAGE=$(grep -oE 'image:[[:space:]]*[^[:space:]]+' "$VSCODE_DIR/docker-compose.yml" \
        | head -1 | awk '{print $2}' | tr -d '"')
    if [[ -n "$IMAGE" ]]; then
        LOCAL_DIGEST=$(docker image inspect "$IMAGE" --format '{{index .RepoDigests 0}}' 2>/dev/null | sed 's/.*@//')
        REMOTE_DIGEST=$(timeout 20 docker buildx imagetools inspect "$IMAGE" --format '{{.Manifest.Digest}}' 2>/dev/null)
        if [[ -n "$LOCAL_DIGEST" && -n "$REMOTE_DIGEST" && "$LOCAL_DIGEST" != "$REMOTE_DIGEST" ]]; then
            VSCODE=yes
        fi
    fi
fi

TMP_FILE=$(mktemp)
{
    printf 'TIMESTAMP=%s\n' "$(date +%s)"
    printf 'APT_COUNT=%s\n' "$APT_COUNT"
    printf 'REBOOT=%s\n' "$REBOOT"
    printf 'NPM_OUTDATED=%s\n' "$NPM_OUTDATED"
    printf 'VSCODE=%s\n' "$VSCODE"
} > "$TMP_FILE"
mv "$TMP_FILE" "$CACHE_FILE"

print_summary() {
    local found=no
    if [[ "${APT_COUNT:-0}" -gt 0 ]]; then
        printf 'apt: %s package(s) to upgrade\n' "$APT_COUNT"
        found=yes
    fi
    if [[ -n "$NPM_OUTDATED" ]]; then
        printf 'npm: %s\n' "$NPM_OUTDATED"
        found=yes
    fi
    if [[ "$VSCODE" == "yes" ]]; then
        printf 'vscode-server: update available\n'
        found=yes
    fi
    if [[ "$REBOOT" == "yes" ]]; then
        printf 'reboot required\n'
        found=yes
    fi
    if [[ "$found" == "no" ]]; then
        printf 'Everything is up to date.\n'
    fi
}

if [[ "${1:-}" == "--print" ]]; then
    print_summary
fi
