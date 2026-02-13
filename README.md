# AIBox

Scripts for managing an AI development virtual machine and integrating with LM Studio.

## Setup

### Host Machine (your computer)

1. Clone this repository:
   ```bash
   git clone https://github.com/malko/aibox.git
   cd aibox
   ```

2. Configure `aibox.sh` - edit the variables at the top:
   - `VM_NAME`: Your KVM/QEMU VM name (from `virsh list --all`)
   - `GUEST_USER`: Your username inside the VM

3. Install dependencies on host:
   ```bash
   sudo apt install virsh libvirt-client
   ```

### Guest VM (inside the KVM/QEMU virtual machine)

1. Create a KVM/QEMU VM with:
   - SSH key authentication (disable password login)
   - At least 4GB RAM, 4+ cores recommended

2. Install inside the VM:
   ```bash
   # Install nvm and node
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   source ~/.bashrc
   nvm install 24
   nvm use 24
   
   # Install opencode
   npm install -g opencode
   
   # Install dependencies
   sudo apt install curl jq netcat-openbsd
   ```

3. Configure opencode:
   ```bash
   # Edit ~/.config/opencode/opencode.json to add your local AI servers
   # For LM Studio, use: http://localhost:1234
   # For Ollama, use: http://localhost:11434
   ```

4. Run the service installer (auto-starts opencode-web at boot):
   ```bash
   ./service_install.sh
   ```

5. Optional: Sync LM Studio models:
   ```bash
   ./update-opencode-models.sh
   ```

### Usage

```bash
# Connect to VM with port forwarding
./aibox.sh 8081:80 3000

# Forward host 3000 to guest 3000
./aibox.sh 3000
```

### Security Notes

- Create a separate git account for your agents—never let the VM push directly to your main repositories
- Be extremely cautious with repository permissions given to agent accounts
- Keep your SSH keys secure and never commit them, never put them in place your agents can access it
- Your ai should NEVER have access to your secrets

## Files

### `aibox.sh` (run in host context)

Manages a KVM/QEMU virtual machine (ai-agentbox) with automatic port forwarding.

**Features:**
- Starts the VM automatically if not running
- Dynamically detects guest IP address
- Sets up SSH port forwarding (supports host:guest or same-port syntax)

**Usage:**
```bash
./aibox.sh [host_port:guest_port] [port] ...

./aibox.sh 8081:80       # Forward host 8081 to guest 80
./aibox.sh 3000          # Forward host 3000 to guest 3000
./aibox.sh 8081:80 3000  # Forward both ports
```

**Configuration:**
- `VM_NAME`: Set to your VM name (from `virsh list --all`)
- `GUEST_USER`: Your username inside the VM

### `update-opencode-models.sh`

Fetches model information from LM Studio and updates opencode's configuration.

**Features:**
- Connects to LM Studio API and retrieves available models
- Auto-detects model properties:
  - Context limits
  - Reasoning capabilities (thinking models)
  - Vision model support (VLM)
  - Special handling for GPT-OSS models
- Updates `~/.config/opencode/opencode.json` with proper model configs
- Creates a backup of the original config

**Usage:**
```bash
./update-opencode-models.sh
```

**Requirements:**
- LM Studio running with API enabled at `http://desk.home:1234`
- `curl`, `jq`, `base64` utilities installed
- opencode config at `~/.config/opencode/opencode.json`

### `service_install.sh`

Installs and enables opencode-web as a systemd user service with automatic startup at boot.

**Features:**
- Auto-detects opencode path (supports nvm-installed node)
- Creates a wrapper script to handle nvm environment
- Idempotent (safe to run multiple times)
- Enables systemd user service and lingering

**Usage:**
```bash
./service_install.sh
```

**What it does:**
1. Detects opencode binary location
2. Creates wrapper script at `~/.local/bin/opencode-web-runner`
3. Creates systemd service at `~/.config/systemd/user/opencode-web.service`
4. Enables and starts the service
5. Enables lingering with `loginctl enable-linger`

**Commands to manage the service:**
```bash
systemctl --user status opencode-web.service
systemctl --user restart opencode-web.service
journalctl --user -u opencode-web.service -f
```

## Notes

- VM name and guest user are hardcoded in `aibox.sh`—edit the script to customize
- LM Studio URL is configured in `update-opencode-models.sh` (currently `http://desk.home:1234`)
