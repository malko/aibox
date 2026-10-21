#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"
source "$SCRIPT_DIR/sudo-funcs.sh"

print_info "=== Install AIBOX MOTD ==="

# Render the banner now (setup time), not at every login: the MOTD file simply
# prints the precomputed strings below.
AIBOX_LOGO_TC=$(aibox_banner_render 24)
AIBOX_LOGO_256=$(aibox_banner_render 256)

cat > /tmp/motd.sh << 'MOTDEND'
#!/bin/sh
# AIBOX MOTD: static banner + dynamic web service URLs.

# Print only once, even when several startup files source this script
# (bash reads /etc/profile.d, zsh is hooked from /etc/zsh/zprofile).
[ -n "${AIBOX_MOTD_SHOWN:-}" ] && return 0
AIBOX_MOTD_SHOWN=1

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[0;90m'
NC='\033[0m'

printf "\n"
AIBOX_LOGO_TC='@AIBOX_LOGO_TC@'
AIBOX_LOGO_256='@AIBOX_LOGO_256@'
case "${COLORTERM:-}${TERM:-}" in
    *truecolor*|*24bit*|*direct*) printf '%s' "$AIBOX_LOGO_TC" ;;
    *) printf '%s' "$AIBOX_LOGO_256" ;;
esac
printf "\n"

# systemctl --user and journalctl --user are required to inspect the services.
if ! command -v systemctl >/dev/null 2>&1; then
    exit 0
fi

# is_service_active <unit> -> success if the user unit exists and is running.
is_service_active() {
    systemctl --user is-active --quiet "$1" 2>/dev/null
}

# service_journal <unit> -> the unit's journal since its last start.
# Reading the whole journal of a verbose service (opencode) costs several
# seconds at every login, so only the current run is read; the last 500 lines
# are used as a fallback when the start timestamp is unavailable.
service_journal() {
    SINCE=$(systemctl --user show -p ActiveEnterTimestamp --value "$1" 2>/dev/null)
    if [ -n "$SINCE" ]; then
        journalctl --user -u "$1" --since "$SINCE" --no-pager -o cat 2>/dev/null
    else
        journalctl --user -u "$1" -n 500 --no-pager -o cat 2>/dev/null
    fi
}

# last_url <unit> [filter] -> most recent URL found in the unit's journal.
last_url() {
    service_journal "$1" \
        | tr -d '\033' \
        | grep -E "${2:-}" \
        | grep -oE 'https?://[^[:space:]"]+' \
        | tail -n 1
}

# last_password <unit> -> most recent "server password <key>" from the journal.
# opencode serve generates this key at startup, like dsh generates its token.
last_password() {
    service_journal "$1" \
        | tr -d '\033' \
        | sed -nE 's/.*server password ([^[:space:]]+).*/\1/p' \
        | tail -n 1
}

SHOWN=false

if is_service_active opencode.service; then
    # opencode serve prints "server listening on http://<ip>:<port>" followed by
    # "server password <key>".
    OPENCODE_URL=$(last_url opencode.service 'server listening')
    OPENCODE_PASSWORD=$(last_password opencode.service)
    if [ -n "$OPENCODE_URL" ]; then
        SHOWN=true
        printf "%b\n" "  ${GREEN}●${NC} opencode      ${CYAN}${OPENCODE_URL}${NC}"
        if [ -n "$OPENCODE_PASSWORD" ]; then
            printf "%b\n" "                  ${DIM}password:${NC} ${OPENCODE_PASSWORD}"
        fi
    fi
fi

if is_service_active dsh-web.service; then
    # dsh prints "dsh web: http://127.0.0.1:<port>/?token=<token>".
    DSH_URL=$(last_url dsh-web.service)
    if [ -n "$DSH_URL" ]; then
        SHOWN=true
        printf "%b\n" "  ${GREEN}●${NC} dsh-web       ${CYAN}${DSH_URL}${NC}"
    fi
fi

# vscode-server runs as a Docker container (codercom/code-server).
if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx vscode-server; then
    # Published host port for the container's 8080/tcp (e.g. 0.0.0.0:8081->8080/tcp).
    VSCODE_PORT=$(docker port vscode-server 8080/tcp 2>/dev/null | head -n 1 | sed 's/.*://')
    if [ -n "$VSCODE_PORT" ]; then
        SHOWN=true
        printf "%b\n" "  ${GREEN}●${NC} vscode-server ${CYAN}http://localhost:${VSCODE_PORT}${NC}"
    fi
fi

if [ "$SHOWN" = true ]; then
    printf "%b\n" "  ${DIM}stop: systemctl --user stop <service>${NC}"
    printf "\n"
fi

# Update summary, cached by aibox-update-check.service (skip if stale).
UPDATES_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/aibox/updates"
if [ -f "$UPDATES_CACHE" ]; then
    cache_get() { grep "^$1=" "$UPDATES_CACHE" 2>/dev/null | head -n 1 | cut -d= -f2-; }

    TS=$(cache_get TIMESTAMP)
    APT_COUNT=$(cache_get APT_COUNT)
    REBOOT=$(cache_get REBOOT)
    NPM_OUTDATED=$(cache_get NPM_OUTDATED)
    VSCODE=$(cache_get VSCODE)

    # Ignore a cache written before the current boot: it may predate a reboot
    # (e.g. a stale "reboot required") until the timer refreshes it.
    NOW=$(date +%s)
    UPTIME=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
    BOOT=$((NOW - UPTIME))

    if [ -n "$TS" ] && [ "$TS" -ge "$BOOT" ] && [ $((NOW - TS)) -lt 172800 ]; then
        if [ "${APT_COUNT:-0}" -gt 0 ] 2>/dev/null || [ -n "$NPM_OUTDATED" ] \
            || [ "$VSCODE" = "yes" ] || [ "$REBOOT" = "yes" ]; then
            printf "%b\n" "  ${YELLOW}⚠ Updates available${NC}"
            [ "${APT_COUNT:-0}" -gt 0 ] 2>/dev/null && printf "    apt: %s package(s) to upgrade\n" "$APT_COUNT"
            [ -n "$NPM_OUTDATED" ] && printf "    npm: %s\n" "$NPM_OUTDATED"
            [ "$VSCODE" = "yes" ] && printf "    vscode-server: update available\n"
            [ "$REBOOT" = "yes" ] && printf "%b\n" "    ${RED}reboot required${NC}"
            printf "\n"
        fi
    fi
fi
MOTDEND

# Inject the precomputed banners (kept out of the quoted heredoc above).
MOTD_CONTENT=$(cat /tmp/motd.sh)
MOTD_CONTENT=${MOTD_CONTENT//@AIBOX_LOGO_TC@/$AIBOX_LOGO_TC}
MOTD_CONTENT=${MOTD_CONTENT//@AIBOX_LOGO_256@/$AIBOX_LOGO_256}
printf '%s\n' "$MOTD_CONTENT" > /tmp/motd.sh

sudo_cmd cp /tmp/motd.sh /etc/profile.d/motd.sh
sudo_cmd chmod +x /etc/profile.d/motd.sh

# zsh does not read /etc/profile.d: hook the MOTD into its login startup.
ZSH_PROFILE=/etc/zsh/zprofile
if [ -f "$ZSH_PROFILE" ] && ! grep -q 'aibox MOTD' "$ZSH_PROFILE"; then
    print_info "Hooking the MOTD into $ZSH_PROFILE (zsh)"
    sudo_cmd sh -c 'printf "\n# aibox MOTD (zsh does not read /etc/profile.d)\n[ -r /etc/profile.d/motd.sh ] && . /etc/profile.d/motd.sh\n" >> "$1"' _ \
        "$ZSH_PROFILE"
fi

print_success "AIBOX MOTD configured!"
