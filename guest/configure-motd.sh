#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Configure MOTD ==="

cat > /tmp/motd.sh << 'MOTDEND'
#!/bin/sh
# AIBOX MOTD: static banner + dynamic web service URLs.

CYAN='\033[0;36m'
GREEN='\033[0;32m'
DIM='\033[0;90m'
NC='\033[0m'

printf "\n"
printf "%b\n" "${CYAN}       d8888 d8b 888888b.                    ${NC}"
printf "%b\n" "${CYAN}      d88888 Y8P 888  °88b                   ${NC}"
printf "%b\n" "${CYAN}     d88P888     888  .88P                   ${NC}"
printf "%b\n" "${CYAN}    d88P 888 888 8888888K.   .d88b.  888  888${NC}"
printf "%b\n" "${CYAN}   d88P  888 888 888  ¨Y88b d88°°88b ¨Y8bd8P¨${NC}"
printf "%b\n" "${CYAN}  d88P   888 888 888    888 888  888   X88K  ${NC}"
printf "%b\n" "${CYAN} d8888888888 888 888   d88P Y88..88P .d8¨¨8b.${NC}"
printf "%b\n" "${CYAN}d88P     888 888 8888888P°   °Y88P°  888  888${NC}"
printf "\n"

# systemctl --user and journalctl --user are required to inspect the services.
if ! command -v systemctl >/dev/null 2>&1; then
    exit 0
fi

# is_service_active <unit> -> success if the user unit exists and is running.
is_service_active() {
    systemctl --user is-active --quiet "$1" 2>/dev/null
}

# last_url <unit> [filter] -> most recent URL found in the unit's journal.
last_url() {
    journalctl --user -u "$1" --no-pager -o cat 2>/dev/null \
        | tr -d '\033' \
        | grep -E "${2:-}" \
        | grep -oE 'https?://[^[:space:]"]+' \
        | tail -n 1
}

SHOWN=false

if is_service_active opencode-web.service; then
    # opencode prints "Network access: http://<ip>:<port>"; fall back to any URL.
    OPENCODE_URL=$(last_url opencode-web.service 'Network access')
    [ -z "$OPENCODE_URL" ] && OPENCODE_URL=$(last_url opencode-web.service)
    if [ -n "$OPENCODE_URL" ]; then
        SHOWN=true
        printf "%b\n" "  ${GREEN}●${NC} opencode-web  ${CYAN}${OPENCODE_URL}${NC}"
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

if [ "$SHOWN" = true ]; then
    printf "%b\n" "  ${DIM}stop: systemctl --user stop <service>${NC}"
    printf "\n"
fi
MOTDEND

sudo cp /tmp/motd.sh /etc/profile.d/motd.sh
sudo chmod +x /etc/profile.d/motd.sh

print_success "AIBOX MOTD configured!"
