#!/bin/bash

# --- CONFIGURATION ---
VM_NAME="ai-agentbox"       # Use the name from 'virsh list --all'
GUEST_USER="malko"      # Your username inside the VM

usage() {
    echo "Usage: $0 [options] [host_port:guest_port] [port] ..."
    echo "Examples:"
    echo "  $0 8081:80       # Forward Host 8081 to Guest 80"
    echo "  $0 3000          # Forward Host 3000 to Guest 3000"
    echo "  $0 8081:80 3000  # Do both at once"
    echo "  $0 -w            # Connect and open browser to NPM (HTTPS)"
    echo ""
    echo "Options:"
    echo "  -w, --open-web  Open browser to https://hostname.local:8443 after connecting"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Note: Port forwarding ends automatically when the SSH session closes."
    exit 0
}

OPEN_WEB=false

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Parse options
while [[ "$1" == "-"* ]]; do
    case "$1" in
        -w|--open-web)
            OPEN_WEB=true
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# Default port forwarding if none provided and -w is used
if [[ $# -eq 0 && "$OPEN_WEB" == "true" ]]; then
    set -- "8443"
fi

# Start VM if it's not running
VM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null)
if [ "$VM_STATE" != "running" ]; then
    echo "🚀 Starting $VM_NAME..."
    virsh start "$VM_NAME"
fi

# Dynamic IP Detection
echo -n "🔍 Detecting Guest IP..."
# We loop because the network lease might take a second to appear after boot
for i in {1..20}; do
    GUEST_IP=$(virsh domifaddr "$VM_NAME" --source lease | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)
    if [ -n "$GUEST_IP" ]; then
        break
    fi
    printf "."
    sleep 1
done

if [ -z "$GUEST_IP" ]; then
    echo -e "\n❌ Error: Could not detect Guest IP. Check 'virsh net-list'?"
    exit 1
fi
echo -e "\n✅ Found IP: $GUEST_IP"


# Build the Forwarding String
FORWARD_ARGS=""
for ARG in "$@"; do
    if [[ "$ARG" == *:* ]]; then
        # Split by colon: HOST_PORT:GUEST_PORT
        HOST_PORT="${ARG%%:*}"
        GUEST_PORT="${ARG#*:}"
    else
        # Single number: Use for both
        HOST_PORT="$ARG"
        GUEST_PORT="$ARG"
    fi
    
    # 0.0.0.0 allows external network access to these ports
    FORWARD_ARGS="$FORWARD_ARGS -L 0.0.0.0:$HOST_PORT:localhost:$GUEST_PORT"
done

# Wait for SSH to be ready
echo -n "🔑 Waiting for SSH..."
while ! nc -z -w 1 "$GUEST_IP" 22 &>/dev/null; do
    printf "."
    sleep 1
done
echo -e "\n✅ SSH is ready!"

# Connect
if [ -n "$FORWARD_ARGS" ]; then
    echo "🔗 Connectint to $GUEST_USER@$GUEST_IP with	active Tunnels: $FORWARD_ARGS"
else
    echo "🔗 Connecting to $GUEST_USER@$GUEST_IP..."
fi

# Open browser if -w flag is set
if [[ "$OPEN_WEB" == "true" && -n "$FORWARD_ARGS" ]]; then
    # Extract the host port from FORWARD_ARGS
    HOST_PORT=$(echo "$FORWARD_ARGS" | grep -oE '[0-9]+:localhost:[0-9]+' | head -1 | cut -d: -f1)
    HOSTNAME_LOCAL=$(hostname).local
    BROWSER_URL="https://${HOSTNAME_LOCAL}:${HOST_PORT}"
    
    echo "🌐 Opening browser to $BROWSER_URL..."
    if command -v xdg-open &>/dev/null; then
        xdg-open "$BROWSER_URL" &>/dev/null &
    elif command -v open &>/dev/null; then
        open "$BROWSER_URL" &>/dev/null &
    else
        print_warn "Could not detect browser opener. Please open $BROWSER_URL manually."
    fi
fi

ssh -o ConnectTimeout=5 $FORWARD_ARGS "$GUEST_USER@$GUEST_IP"

