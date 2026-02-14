#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_ascii_logo() {
    echo -e "${CYAN}"
    cat << 'EOF'
       d8888 d8b 888888b.                    
      d88888 Y8P 888  "88b                   
     d88P888     888  .88P                   
    d88P 888 888 8888888K.   .d88b.  888  888
   d88P  888 888 888  "Y88b d88""88b `Y8bd8P'
  d88P   888 888 888    888 888  888   X88K  
 d8888888888 888 888   d88P Y88..88P .d8""8b.
d88P     888 888 8888888P"   "Y88P"  888  888
EOF
    echo -e "${NC}"
}

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}" >&2; }

prompt() {
    local prompt_text="$1"
    local default="$2"
    local result
    if [[ -n "$default" ]]; then
        read -p "$prompt_text [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt_text: " result
        echo "$result"
    fi
}

prompt_yes_no() {
    local prompt_text="$1"
    local default="$2"
    local result
    while true; do
        if [[ "$default" == "yes" ]]; then
            read -p "$prompt_text [Y/n]: " result
            result="${result:-y}"
        else
            read -p "$prompt_text [y/N]: " result
            result="${result:-n}"
        fi
        case "$result" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
        esac
    done
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        print_error "Command '$1' not found. Install it and try again."
        exit 1
    fi
}

print_ascii_logo

HOSTNAME_LOCAL=$(hostname).local
print_info "=== AIBox VM Setup Script ==="
print_info "This script will help configure your VM as an AIBox"
print_info "Host detected: $HOSTNAME_LOCAL"
echo ""

VM_NAME=$(prompt "VM name" "aibox")
print_info "Checking if VM '$VM_NAME' exists..."

if ! virsh dominfo "$VM_NAME" &>/dev/null; then
    print_warn "VM '$VM_NAME' does not exist."
    
    if prompt_yes_no "Do you want to create a new VM?" "yes"; then
        echo ""
        print_info "=== VM Configuration ==="
        
        ISO_PATH=$(prompt "Path to Ubuntu ISO" "")
        VCPU=$(prompt "Number of CPUs" "4")
        RAM=$(prompt "RAM in MB" "4096")
        DISK_SIZE=$(prompt "Disk size (e.g., 20G)" "20G")
        NETWORK=$(prompt "Network" "default")
        
        print_info "Creating VM '$VM_NAME'..."
        
        virt-install \
            --name "$VM_NAME" \
            --vcpus "$VCPU" \
            --ram "$RAM" \
            --disk path="/var/lib/libvirt/images/${VM_NAME}.qcow2,size=${DISK_SIZE}" \
            --os-variant ubuntu24.04 \
            --network network="$NETWORK" \
            --graphics none \
            --console pty,target_type=serial \
            --location "$ISO_PATH" \
            --extra-args 'console=ttyS0,115200n8 serial'
        
        print_success "VM created!"
        echo ""
        print_warn "=== Next Steps ==="
        print_info "1. Install Ubuntu LTS in the VM (use the console)"
        print_info "2. Create a user account (e.g., 'aibox')"
        print_info "3. After installation, restart the VM and run this script again"
        exit 0
    else
        print_error "VM creation cancelled. Please create a VM first, then run this script."
        exit 1
    fi
fi

print_success "VM '$VM_NAME' found!"

print_info "Starting VM..."
virsh start "$VM_NAME" 2>/dev/null || true

print_info "Waiting for VM to boot..."
sleep 5

GUEST_IP=""
for i in {1..30}; do
    GUEST_IP=$(virsh domifaddr "$VM_NAME" --source lease 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)
    if [[ -n "$GUEST_IP" ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [[ -z "$GUEST_IP" ]]; then
    print_error "Could not detect VM IP. Make sure the VM is running and has network connectivity."
    exit 1
fi
print_success "VM IP: $GUEST_IP"

print_info "Waiting for SSH..."
for i in {1..30}; do
    if nc -z -w 1 "$GUEST_IP" 22 &>/dev/null; then
        print_success "SSH is ready!"
        break
    fi
    sleep 1
done

if ! nc -z -w 1 "$GUEST_IP" 22 &>/dev/null; then
    print_error "SSH is not responding. Make sure openssh-server is installed in the VM."
    exit 1
fi

echo ""
print_info "=== SSH Configuration ==="

GUEST_USER=$(prompt "VM username" "aibox")

# Check if SSH key auth already works
print_info "Checking if SSH key authentication is already configured..."
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

if [[ -f "$SSH_KEY_PATH" && -f "${SSH_KEY_PATH}.pub" ]]; then
    if ssh -o ConnectTimeout=5 -o PasswordAuthentication=no "$GUEST_USER@$GUEST_IP" "echo 'SSH key auth works!'" &>/dev/null; then
        print_success "SSH key authentication already configured!"
    else
        # Need to configure SSH key
        print_info "SSH key not configured. Setting up now..."
        
        if [[ -z "$SSH_KEY_PATH" ]]; then
            print_info "Creating new SSH key..."
            SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
            if [[ -f "$SSH_KEY_PATH" ]]; then
                if prompt_yes_no "Key already exists at $SSH_KEY_PATH. Use it?" "yes"; then
                    :
                else
                    SSH_KEY_PATH=$(prompt "Enter new key path" "$HOME/.ssh/id_ed25519")
                fi
            else
                ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
            fi
        fi

        if [[ ! -f "${SSH_KEY_PATH}.pub" ]]; then
            print_error "Public key not found: ${SSH_KEY_PATH}.pub"
            exit 1
        fi

        print_info "Copying SSH key to VM..."
        ssh-copy-id -i "${SSH_KEY_PATH}.pub" -o ConnectTimeout=10 "${GUEST_USER}@${GUEST_IP}" 2>/dev/null || {
            print_error "Failed to copy SSH key. Make sure you can connect with password."
            exit 1
        }
        print_success "SSH key configured!"

        print_info "Verifying SSH key authentication..."
        if ssh -t -o ConnectTimeout=10 -o PasswordAuthentication=no "$GUEST_USER@$GUEST_IP" "echo 'SSH key auth works!'" &>/dev/null; then
            print_success "SSH key authentication verified!"
        else
            print_error "SSH key authentication failed. Please check and try again."
            exit 1
        fi
    fi
else
    print_error "No SSH key found at $SSH_KEY_PATH. Please create one first."
    exit 1
fi

if prompt_yes_no "Disable password authentication in VM?" "yes"; then
    print_info "Disabling password authentication..."
    
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << 'EOF'
sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
EOF
    print_success "Password authentication disabled!"
fi

echo ""
print_info "=== Installing Dependencies in VM ==="

ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << 'EOF'
set -e

echo "Updating packages..."
sudo apt update
sudo apt install -y curl jq netcat-openbsd git

if ! command -v nvm &>/dev/null && [ ! -d "$HOME/.nvm" ]; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
    echo "Installing Node.js..."
    nvm install 24
    nvm use 24
fi

if ! command -v opencode &>/dev/null; then
    echo "Installing opencode..."
    npm install -g opencode
fi

echo "Dependencies installed!"
EOF

print_success "Dependencies installed!"

echo ""
print_info "=== Git Configuration ==="

ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
set -e

git config --global user.name "${GUEST_USER}-aibox"
git config --global user.email "${GUEST_USER}@aibox.local"

echo "Git configured!"
EOF

print_success "Git configured with user: ${GUEST_USER}-aibox"

echo ""
print_info "=== MOTD Configuration ==="

if prompt_yes_no "Set AIBOX logo as MOTD (Message of the Day)?" "yes"; then
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << 'MOTDEOF'
set -e

sudo tee /etc/profile.d/motd.sh > /dev/null << 'MOTD'
#!/bin/sh
echo ""
echo "       d8888 d8b 888888b.                    "
echo "      d88888 Y8P 888  "88b                   "
echo "     d88P888     888  .88P                   "
echo "    d88P 888 888 8888888K.   .d88b.  888  888"
echo "   d88P  888 888 888  "Y88b d88""88b `Y8bd8P'"
echo "  d88P   888 888 888    888 888  888   X88K  "
echo " d8888888888 888 888   d88P Y88..88P .d8""8b."
echo "d88P     888 888 8888888P"   "Y88P"  888  888"
echo ""
MOTD

sudo chmod +x /etc/profile.d/motd.sh

echo "MOTD configured!"
MOTDEOF
    print_success "AIBOX MOTD configured!"
fi

echo ""
print_info "=== Git Directory Setup ==="

ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
set -e

mkdir -p ~/git
mkdir -p ~/scripts

echo "Git and scripts directories created!"
EOF

print_success "Git and scripts directories created!"

echo ""
print_info "=== Docker Installation ==="

if prompt_yes_no "Install Docker and Nginx Proxy Manager?" "yes"; then
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << 'DOCKEREOF'
set -e

echo "Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker "$USER"
fi

echo "Docker installed!"
DOCKEREOF

    print_success "Docker installed!"

    NPM_PORT=$(prompt "NPM HTTPS port (e.g., 8443)" "8443")
    
    while true; do
        read -s -p "Enter password for opencode-web access: " NPM_AUTH_PASSWORD
        echo ""
        if [[ -z "$NPM_AUTH_PASSWORD" ]]; then
            print_error "Password cannot be empty"
            continue
        fi
        read -s -p "Confirm password: " NPM_AUTH_PASSWORD_CONFIRM
        echo ""
        if [[ "$NPM_AUTH_PASSWORD" == "$NPM_AUTH_PASSWORD_CONFIRM" ]]; then
            break
        else
            print_error "Passwords do not match, try again"
        fi
    done

    print_info "Setting up NPM data directory..."
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
set -e

mkdir -p ~/npm-data
mkdir -p ~/docker

echo "NPM data directory created!"
EOF

    print_info "Creating docker-compose.yml for NPM..."
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << 'NPMEOF'
set -e

cat > ~/docker/docker-compose.yml << 'YAML'
version: '3.8'
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '8181:8181'
    volumes:
      - ~/npm-data:/data
      - ~/npm-data/letsencrypt:/etc/letsencrypt
    environment:
      - DB_SQLITE_FILE=/data/database.db
YAML

echo "docker-compose.yml created!"
NPMEOF

    print_info "Starting NPM container..."
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << 'NPMEOF'
set -e

cd ~/docker
docker compose up -d

echo "Waiting for NPM to start..."
sleep 10

echo "NPM container started!"
NPMEOF

    print_info "Waiting for NPM to be ready..."
    for i in {1..30}; do
        if ssh -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" "nc -z localhost 8181" 2>/dev/null; then
            print_success "NPM is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""

    NPM_DEFAULT_EMAIL="admin@aibox.local"
    NPM_DEFAULT_USER="admin"
    NPM_DEFAULT_PASSWORD="$NPM_AUTH_PASSWORD"

    print_info "Configuring NPM..."
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
set -e

cd ~/docker

# Wait for NPM API to be fully ready
for i in {1..30}; do
    if curl -s http://localhost:8181/api > /dev/null 2>&1; then
        break
    fi
    sleep 2
done

# Get initial admin token
echo "Getting admin token..."
TOKEN_RESPONSE=\$(curl -s -X POST http://localhost:8181/api/users/admin/auth \\
    -H "Content-Type: application/json" \\
    -d '{"email":"$NPM_DEFAULT_EMAIL","password":"$NPM_DEFAULT_PASSWORD"}')

TOKEN=\$(echo \$TOKEN_RESPONSE | jq -r '.token // empty')

if [[ -z "\$TOKEN" ]]; then
    # Try to create the user if it doesn't exist
    echo "Creating admin user..."
    curl -s -X POST http://localhost:8181/api/users \\
        -H "Content-Type: application/json" \\
        -d '{"email":"$NPM_DEFAULT_EMAIL","name":"Admin","password":"$NPM_DEFAULT_PASSWORD"}'
    
    sleep 2
    
    TOKEN_RESPONSE=\$(curl -s -X POST http://localhost:8181/api/users/admin/auth \\
        -H "Content-Type: application/json" \\
        -d '{"email":"$NPM_DEFAULT_EMAIL","password":"$NPM_DEFAULT_PASSWORD"}')
    
    TOKEN=\$(echo \$TOKEN_RESPONSE | jq -r '.token // empty')
fi

if [[ -z "\$TOKEN" ]]; then
    echo "Failed to get admin token. Please configure NPM manually at http://localhost:8181"
    exit 1
fi

echo "Admin token obtained!"

# Create proxy host for opencode-web
echo "Creating proxy host..."
curl -s -X POST http://localhost:8181/api/nginx/proxies \\
    -H "Content-Type: application/json" \\
    -H "Authorization: Bearer \$TOKEN" \\
    -d '{
        "domain_names": ["opencode"],
        "forward_scheme": "http",
        "forward_host": "localhost",
        "forward_port": 4096,
        "access_list_id": "0",
        "enable_ssl": true,
        "ssl_cert": "npm",
        "ssl_key": "npm",
        "metadata": {"basic_auth": "|opencode|${NPM_AUTH_PASSWORD}|"}
    }'

echo "Proxy host created!"

# Save port to file for aibox.sh
echo "$NPM_PORT" > ~/npm-port
echo "NPM configured!"
EOF

    print_success "Nginx Proxy Manager configured!"
    
    NPM_PORT_CONFIGURED=true
else
    NPM_PORT_CONFIGURED=false
fi

echo ""
print_info "=== OpenCode Configuration ==="

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"

mkdir -p "$OPENCODE_CONFIG_DIR"

cat > "$OPENCODE_CONFIG_FILE" << 'EOF'
{
  "provider": {}
}
EOF

print_info "OpenCode config initialized at $OPENCODE_CONFIG_FILE"

echo ""
print_info "=== LLM Server Configuration ==="

CONFIGURE_LLM=false
OLLAMA_URL=""
LMS_URL=""

if prompt_yes_no "Configure Ollama server?" "no"; then
    OLLAMA_URL=$(prompt "Ollama URL (host)" "http://${HOSTNAME_LOCAL}:11434")
    CONFIGURE_LLM=true
fi

if prompt_yes_no "Configure LM Studio server?" "no"; then
    LMS_URL=$(prompt "LM Studio URL (host)" "http://${HOSTNAME_LOCAL}:1234")
    CONFIGURE_LLM=true
fi

if [[ "$CONFIGURE_LLM" == "true" ]]; then
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
set -e

mkdir -p "$OPENCODE_CONFIG_DIR"

EOF

    if [[ -n "$OLLAMA_URL" ]]; then
        print_info "Adding Ollama provider to opencode config..."
        ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
set -e

jq '.provider += {
  "ollama": {
    "url": "$OLLAMA_URL",
    "name": "Ollama (local)",
    "models": {}
  }
}' $OPENCODE_CONFIG_FILE > tmp.json && mv tmp.json $OPENCODE_CONFIG_FILE

EOF
    fi

    if [[ -n "$LMS_URL" ]]; then
        print_info "Adding LM Studio provider to opencode config..."
        ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
set -e

jq '.provider += {
  "lms": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "LM Studio (local)",
    "options": {
      "baseUrl": "$LMS_URL/v1"
    },
    "models": {}
  }
}' $OPENCODE_CONFIG_FILE > tmp.json && mv tmp.json $OPENCODE_CONFIG_FILE

EOF
    fi

    print_success "LLM providers added to config!"
else
    print_info "No LLM servers configured. You can add them later in opencode.json"
fi

echo ""
print_info "=== Git Share Configuration (virtiofs) ==="

VIRTIOFS_SHARE=false
HOST_SHARE_DIR=""

if prompt_yes_no "Configure git share with host (virtiofs)?" "no"; then
    HOST_SHARE_DIR=$(prompt "Host directory to share" "$HOME/git")
    VIRTIOFS_SHARE=true
    
    mkdir -p "$HOST_SHARE_DIR"
    
    print_info "Adding filesystem to VM..."
    virsh shutdown "$VM_NAME" 2>/dev/null || true
    sleep 3
    
    DOMAIN_XML=$(virsh dumpxml "$VM_NAME")
    
    if echo "$DOMAIN_XML" | grep -q "filesystem"; then
        print_warn "VM already has filesystem configured. Skipping."
    else
        virsh attach-device "$VM_NAME" --persistent --file - <<EOF
<filesystem type="mount" accessmode="passthrough">
  <source dir="$HOST_SHARE_DIR"/>
  <target dir="git-share"/>
</filesystem>
EOF
        print_success "Virtiofs configured on host!"
    fi
fi

if [[ "$VIRTIOFS_SHARE" == "true" ]]; then
    print_info "Configuring virtiofs mount in VM..."
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << 'VMEOF'
set -e

# Add virtiofs to fstab
if ! grep -q "git-share" /etc/fstab; then
    echo "git-share /home/$USER/git virtiofs defaults,x-guest 0 0" | sudo tee -a /etc/fstab
fi

sudo mkdir -p /home/$USER/git
sudo chown $USER:$USER /home/$USER/git

sudo mount -a || true

echo "Virtiofs mount configured!"
VMEOF
fi

echo ""
print_info "=== Uploading Scripts to VM ==="

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

scp -o ConnectTimeout=10 "$SCRIPTS_DIR/update-opencode-models.sh" "$SCRIPTS_DIR/service_install.sh" "$GUEST_USER@${GUEST_IP}:~/scripts/"

ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "chmod +x ~/scripts/*.sh"

print_success "Scripts uploaded!"

echo ""
print_info "=== Installing opencode-web Service ==="

ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "cd ~/scripts && ./service_install.sh"

echo ""
print_warn "=== Setup Complete! ==="
print_success "VM '$VM_NAME' is ready!"
echo ""
print_info "To connect to your VM through ssh, run:"
echo "  ./aibox.sh"

if [[ "$NPM_PORT_CONFIGURED" == "true" ]]; then
    print_info "To access opencode web interface, run:"
    echo "  ./aibox.sh $NPM_PORT"
    echo "  Then open https://${HOSTNAME_LOCAL}:$NPM_PORT"
    echo ""
    print_info "NPM admin UI: http://${HOSTNAME_LOCAL}:8181"
    echo "  User: admin, Password: $NPM_AUTH_PASSWORD"
else
    print_info "To access opencode web interface, run:"
    echo "  ./aibox.sh 4096"
    echo "  Then open http://${HOSTNAME_LOCAL}:4096"
fi

echo ""
print_info "To update opencode models later, run in VM:"
echo "  ~/scripts/update-opencode-models.sh"
