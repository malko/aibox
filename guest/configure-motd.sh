#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Configure MOTD ==="

cat > /tmp/motd.sh << 'MOTDEND'
#!/bin/sh
echo ""
echo "       d8888 d8b 888888b.                    "
echo "      d88888 Y8P 888  °88b                   "
echo "     d88P888     888  .88P                   "
echo "    d88P 888 888 8888888K.   .d88b.  888  888"
echo "   d88P  888 888 888  ¨Y88b d88°°88b ¨Y8bd8P¨"
echo "  d88P   888 888 888    888 888  888   X88K  "
echo " d8888888888 888 888   d88P Y88..88P .d8¨¨8b."
echo "d88P     888 888 8888888P°   °Y88P°  888  888"
echo ""
MOTDEND

sudo cp /tmp/motd.sh /etc/profile.d/motd.sh
sudo chmod +x /etc/profile.d/motd.sh

print_success "AIBOX MOTD configured!"
