# AIBox

Scripts for managing an AI development virtual machine and integrating with LM Studio.

## Files

### `aibox.sh`

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

## Notes

- VM name and guest user are hardcoded in `aibox.sh`—edit the script to customize
- LM Studio URL is configured in `update-opencode-models.sh` (currently `http://desk.home:1234`)
