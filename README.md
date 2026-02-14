# AIBox

Scripts for managing an AI development virtual machine with reverse proxy and service management.

## Quick Start

```bash
# Run automated setup
./setup.sh

# Connect to VM (automatically forwards configured services)
./aibox

# Access opencode-web at http://localhost:4096
```

## Requirements

### Host Machine
- KVM/QEMU with libvirt
- virsh, libvirt-client installed

```bash
sudo apt install virsh libvirt-client
```

### Guest VM
- Ubuntu/Debian VM with SSH access
- At least 4GB RAM, 4+ cores recommended

## Usage

### Connect to VM

```bash
./aibox                      # Connect with all configured services
./aibox 8081:80             # Forward host 8081 to guest 80
./aibox 3000 8081           # Forward multiple ports
./aibox -w                   # Connect and open browser
```

### Service Management

```bash
./aibox service-add opencode 4096           # Add a service
./aibox service-add portainer 8080:9000      # Add with custom port mapping
./aibox service-list                         # List configured services
./aibox service-remove opencode              # Remove a service
```

### VM Management

```bash
./aibox shutdown           # Gracefully shutdown VM
./aibox shutdown -f       # Force shutdown VM

./aibox snapshot create              # Create snapshot (auto name)
./aibox snapshot create my-snap     # Create snapshot (custom name)
./aibox snapshot list                # List snapshots
./aibox snapshot delete my-snap     # Delete snapshot
./aibox snapshot revert my-snap     # Revert to snapshot
```

## Setup Process

The `./setup.sh` script automates everything:

1. Creates VM if needed
2. Starts VM and configures SSH
3. Uploads scripts to VM
4. Installs dependencies (nvm, node, opencode)
5. Configures Git, MOTD
6. Optionally installs Docker
7. Configures LLM providers (Ollama, LM Studio)
8. Optionally configures virtiofs for git share
9. Installs opencode-web as systemd service

## Configuration

### Services Config

Services are stored in `~/.config/aibox/services.json`:

```json
{
  "opencode": "4096",
  "portainer": "8080:9000"
}
```

### AIBox Config

Main config is at `~/.config/aibox/aibox.conf`:

```
VM_NAME="ai-agentbox"
GUEST_USER="malko"
SNAPSHOT_DIR="~/aibox/snapshots"
```

### OpenCode Config

Edit `~/.config/opencode/opencode.json` in the VM to configure AI providers.

## File Structure

```
aibox/
├── aibox                    # Main CLI (VM + port forwarding + commands)
├── setup.sh                 # Automated VM setup
├── cmd/                     # Command scripts
│   ├── service-add          # Add service
│   ├── service-remove      # Remove service
│   ├── service-list        # List services
│   ├── vm-shutdown         # Shutdown VM
│   └── vm-snapshot         # Manage snapshots
├── host/                    # Host-side scripts
│   ├── create-vm.sh        # Create VM
│   ├── start-vm.sh         # Start VM
│   ├── configure-ssh.sh    # SSH setup
│   └── upload-scripts.sh   # Upload to VM
├── guest/                   # Guest-side scripts (uploaded to VM)
│   ├── install-deps.sh     # Install dependencies
│   ├── install-docker.sh   # Install Docker
│   ├── install-service.sh  # Install opencode-web service
│   ├── configure-llm.sh    # Configure LLM providers
│   └── update-opencode-models.sh  # Sync models
└── shared-funcs.sh          # Common functions
```

## Security Notes

- Create a separate git account for your agents
- Never let the VM push directly to main repositories
- Keep SSH keys secure and never commit them
- Your AI should NOT have access to your secrets
