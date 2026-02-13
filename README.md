# AIBox

Scripts for managing an AI development virtual machine and integrating with LM Studio.

## aibox setup
- create a vm for your aibox, this repository is tailored around the following setup:
  - a KVM/QEMU virtual machine 
  - use an ssh key for authentication into the vm and disable login ssh inside the vm
  - use aibox.sh to connect to your vbox (edit config variable at the top of the script)
  - install nvm / node inside your aibox
  - install opencode
  - edit file ~/.config/opencode/opencode.json to add your local ai servers (ollama / lms)
  - for lms you can use the update-opencode-models.sh to update models provided by you lms server.
  - create a git directory and optionnaly share it with your host:
    The idea here is to let user push to repositories from host machine manually, don't let your aibox guest push to your repositories directly. At least create a separate account specifically for your agents and be really cautious about rights you give on your repositories to this account.
  - in the vm activate *lingering*: `sudo loginctl enable-linger $USER`
  - run `service_install.sh` to install and enable the opencode-web systemd service

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
