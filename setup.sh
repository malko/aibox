#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"
source "$SCRIPT_DIR/config-funcs.sh"

CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -c, --config FILE    Path to config file (default: ~/.config/aibox/aibox.conf)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "The config file stores settings between runs. User responses are saved"
            echo "to the config file and used as defaults for subsequent runs."
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use -h for help" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
fi

init_config_file

check_command virsh

print_ascii_logo

HOSTNAME_LOCAL=$(hostname).local
print_info "=== AIBox Setup Script ==="
print_info "This script will configure your VM as an AIBox"
print_info "Host detected: $HOSTNAME_LOCAL"
print_info "Config file: $CONFIG_FILE"
echo ""

VM_NAME=$(prompt_config "VM_NAME" "VM name" "aibox")
save_config "VM_NAME" "$VM_NAME"
print_info "Checking if VM '$VM_NAME' exists..."

if ! virsh dominfo "$VM_NAME" &>/dev/null; then
    print_warn "VM '$VM_NAME' does not exist."
    
    CREATE_VM=$(prompt_config_yes_no "CREATE_VM" "Do you want to create a new VM?" "yes")
    save_config "CREATE_VM" "$CREATE_VM"
    
    if [[ "$CREATE_VM" == "yes" ]]; then
        "$SCRIPT_DIR/host/create-vm.sh" "$VM_NAME"
        exit 0
    else
        print_error "VM creation cancelled."
        exit 1
    fi
fi

print_success "VM '$VM_NAME' found!"

"$SCRIPT_DIR/host/start-vm.sh" "$VM_NAME"

source /tmp/aibox-vm-info
GUEST_USER=$(prompt_config "GUEST_USER" "VM username" "aibox")
save_config "GUEST_USER" "$GUEST_USER"

print_info "Setting up SSH key authentication..."
"$SCRIPT_DIR/host/configure-ssh.sh" "$VM_NAME" "$GUEST_IP" "$GUEST_USER"

echo ""
print_info "=== Guest Configuration ==="
print_info "You will be prompted for sudo password when needed."

ssh -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "mkdir -p ~/scripts"

"$SCRIPT_DIR/host/upload-scripts.sh" "$VM_NAME" "$GUEST_IP" "$GUEST_USER"

DISABLE_PASSWORD_AUTH=$(prompt_config_yes_no "DISABLE_PASSWORD_AUTH" "Disable password authentication in VM?" "yes")
save_config "DISABLE_PASSWORD_AUTH" "$DISABLE_PASSWORD_AUTH"

if [[ "$DISABLE_PASSWORD_AUTH" == "yes" ]]; then
    PASSWORD_AUTH_DISABLED=$(ssh -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" "grep -E '^PasswordAuthentication\s+no' /etc/ssh/sshd_config" 2>/dev/null || echo "")
    if [[ -n "$PASSWORD_AUTH_DISABLED" ]]; then
        print_info "Password authentication already disabled, skipping."
    else
        ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/configure-sshd.sh"
        print_success "Password authentication disabled!"
    fi
fi

INSTALL_DEPS=$(prompt_config_yes_no "INSTALL_DEPS" "Install dependencies in VM?" "yes")
save_config "INSTALL_DEPS" "$INSTALL_DEPS"

if [[ "$INSTALL_DEPS" == "yes" ]]; then
    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/install-deps.sh"
    print_success "Dependencies installed!"
fi

CONFIGURE_GIT=$(prompt_config_yes_no "CONFIGURE_GIT" "Configure Git in VM?" "yes")
save_config "CONFIGURE_GIT" "$CONFIGURE_GIT"

if [[ "$CONFIGURE_GIT" == "yes" ]]; then
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" << EOF
git config --global user.name "${GUEST_USER}-aibox"
git config --global user.email "${GUEST_USER}@aibox.local"

echo "Git configured!"
EOF
    print_success "Git configured!"
fi

CONFIGURE_MOTD=$(prompt_config_yes_no "CONFIGURE_MOTD" "Set AIBOX logo as MOTD?" "yes")
save_config "CONFIGURE_MOTD" "$CONFIGURE_MOTD"

if [[ "$CONFIGURE_MOTD" == "yes" ]]; then
    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/configure-motd.sh"
    print_success "MOTD configured!"
fi

ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "mkdir -p ~/git ~/scripts"
print_success "Directories created!"

INSTALL_DOCKER=$(prompt_config_yes_no "INSTALL_DOCKER" "Install Docker?" "yes")
save_config "INSTALL_DOCKER" "$INSTALL_DOCKER"

if [[ "$INSTALL_DOCKER" == "yes" ]]; then
    DOCKER_INSTALLED=$(ssh -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" "command -v docker" 2>/dev/null || echo "")
    if [[ -n "$DOCKER_INSTALLED" ]]; then
        print_info "Docker already installed, skipping."
    else
        ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/install-docker.sh"
        print_success "Docker installed!"
    fi
fi

OPENCODE_PORT=$(prompt_config "OPENCODE_PORT" "opencode-web port" "4096")
save_config "OPENCODE_PORT" "$OPENCODE_PORT"

print_info "Configuring services..."
mkdir -p "${HOME}/.config/aibox"
SERVICES_FILE="${HOME}/.config/aibox/services.json"
if [[ ! -f "$SERVICES_FILE" ]]; then
    echo "{\"opencode\": \"$OPENCODE_PORT\"}" > "$SERVICES_FILE"
    print_success "Services config created with opencode:$OPENCODE_PORT"
else
    if ! grep -q "opencode" "$SERVICES_FILE" 2>/dev/null; then
        "$SCRIPT_DIR/cmd/service-add" opencode "$OPENCODE_PORT"
    fi
fi

print_info "Configuring OpenCode..."
ssh -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" 'mkdir -p ~/.config/opencode && echo "{ \"provider\": {} }" > ~/.config/opencode/opencode.json'

CONFIGURE_OLLAMA=$(prompt_config_yes_no "CONFIGURE_OLLAMA" "Configure Ollama?" "no")
save_config "CONFIGURE_OLLAMA" "$CONFIGURE_OLLAMA"

CONFIGURE_LMS=$(prompt_config_yes_no "CONFIGURE_LMS" "Configure LM Studio?" "no")
save_config "CONFIGURE_LMS" "$CONFIGURE_LMS"

if [[ "$CONFIGURE_OLLAMA" == "yes" || "$CONFIGURE_LMS" == "yes" ]]; then
    if [[ "$CONFIGURE_OLLAMA" == "yes" ]]; then
        OLLAMA_URL=$(prompt_config "OLLAMA_URL" "Ollama URL" "http://${HOSTNAME_LOCAL}:11434")
        save_config "OLLAMA_URL" "$OLLAMA_URL"
        ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/configure-llm.sh ollama $OLLAMA_URL"
    fi
    
    if [[ "$CONFIGURE_LMS" == "yes" ]]; then
        LMS_URL=$(prompt_config "LMS_URL" "LM Studio URL" "http://${HOSTNAME_LOCAL}:1234")
        save_config "LMS_URL" "$LMS_URL"
        ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/configure-llm.sh lms $LMS_URL"
    fi
    
    print_success "LLM providers configured!"
    
    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/update-opencode-models.sh"
    print_success "OpenCode models updated!"
fi

print_success "OpenCode configured!"

CONFIGURE_VIRTIOFS=$(prompt_config_yes_no "CONFIGURE_VIRTIOFS" "Configure virtiofs (git share with host)?" "no")
save_config "CONFIGURE_VIRTIOFS" "$CONFIGURE_VIRTIOFS"

if [[ "$CONFIGURE_VIRTIOFS" == "yes" ]]; then
    HOST_SHARE_DIR=$(prompt_config "HOST_SHARE_DIR" "Host directory to share" "$HOME/git")
    save_config "HOST_SHARE_DIR" "$HOST_SHARE_DIR"
    mkdir -p "$HOST_SHARE_DIR"
    
    virsh shutdown "$VM_NAME" 2>/dev/null || true
    sleep 3
    
    DOMAIN_XML=$(virsh dumpxml "$VM_NAME")
    if ! echo "$DOMAIN_XML" | grep -q "filesystem"; then
        virsh attach-device "$VM_NAME" --persistent --file - <<EOF
<filesystem type="mount" accessmode="passthrough">
  <source dir="$HOST_SHARE_DIR"/>
  <target dir="git-share"/>
</filesystem>
EOF
    fi
    
    virsh start "$VM_NAME" 2>/dev/null || true
    sleep 5
    
    for i in {1..30}; do
        GUEST_IP_NEW=$(virsh domifaddr "$VM_NAME" --source lease 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)
        if [[ -n "$GUEST_IP_NEW" ]]; then
            break
        fi
        sleep 2
    done
    
    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP_NEW" "set -e
if ! grep -q 'git-share' /etc/fstab; then
    echo 'git-share /home/$USER/git virtiofs defaults,x-guest 0 0' | sudo tee -a /etc/fstab
fi

sudo mkdir -p /home/$USER/git
sudo chown \$USER:\$USER /home/$USER/git

sudo mount -a || true

echo 'Virtiofs configured!'"

print_success "Virtiofs configured!"
fi

print_info "Installing opencode-web service..."
ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "source ~/.bashrc && ~/scripts/install-service.sh"
print_success "Service installed!"

echo ""
print_warn "=== Setup Complete! ==="
print_success "VM '$VM_NAME' is ready!"
echo ""
print_info "To connect to your VM, run:"
echo "  ./aibox"
echo ""
print_info "To access opencode web interface:"
echo "  ./aibox"
echo "  Then open http://localhost:4096"
echo ""
print_info "Or directly on the network (requires /etc/hosts or avahi):"
echo "  http://${HOSTNAME_LOCAL}:4096"
