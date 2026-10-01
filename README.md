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

## Network Model

The VM is deliberately not reachable from your network: guest services listen
on the guest's localhost, and nothing is exposed until you run `aibox`.

`aibox` opens an SSH session to the VM and creates one local tunnel per
service/port:

- services from `~/.config/aibox/services.json` are forwarded automatically;
- extra `[host:]guest` ports can be passed on the command line;
- each tunnel is `-L 0.0.0.0:<host_port>:127.0.0.1:<guest_port>`, so a service
  is reachable at `http://localhost:<host_port>` while the session runs;
- `-n/--no-service` connects without forwarding the configured services;
- `-p/--peon-relay` additionally opens a reverse tunnel (guest to host,
  port 19998).

Because the ports are bound on `0.0.0.0`, the forwarded services are also
reachable from the LAN via `http://<hostname>.local:<host_port>` — but only
while `aibox` is running. Closing the SSH session (Ctrl-D, network drop, laptop
sleep) tears all the tunnels down and the services become unreachable again.

In short: no `aibox` session, no exposed service. This is why the opencode web
interface is at `http://localhost:4096` rather than on the VM's IP.

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
./aibox restart            # Gracefully restart VM
./aibox restart -f        # Force restart VM

./aibox snapshot create              # Create snapshot (auto name, internal qcow2)
./aibox snapshot create my-snap     # Create snapshot (custom name, internal qcow2)
./aibox snapshot list                # List snapshots
./aibox snapshot delete my-snap     # Delete snapshot
./aibox snapshot revert my-snap     # Revert to snapshot

Note: Snapshots are internal (embedded in qcow2 file). VM must be shut off to create.
```

### Updates

```bash
./aibox update scripts            # Upload the latest scripts to the VM
./aibox update os                 # apt update + dist-upgrade (interactive)
./aibox update os -y              # Same, non-interactive
./aibox update opencode           # Update opencode + restart opencode-web
./aibox update dsh                # Update dsh + restart dsh-web
./aibox update vscode-server      # Pull and restart vscode-server
./aibox update all                # scripts, os, opencode, dsh, vscode-server
./aibox check-updates             # Check for updates (aibox repo + VM)
./aibox self-update               # Pull the aibox repo and push scripts to the VM
```

`all` stops at the first failure. `opencode-password` is excluded (it is an
interactive config action).

## Setup Process

The `./setup.sh` script (also available as `aibox setup`) runs the VM setup as
independent, replayable steps. Prerequisites of a step are run automatically,
so you can re-run just one part without redoing everything.

```bash
./setup.sh                    # Run every step ('all')
./setup.sh motd               # Reconfigure the MOTD only
./setup.sh dsh                # Install dsh and its web service
./setup.sh motd dsh           # Several steps in one run
aibox setup motd              # Same, through the main CLI
./setup.sh --help             # List all steps
```

Steps (in order): `vm`, `ssh`, `scripts`, `deps`, `sshd`, `git`, `dirs`,
`hosts`, `motd`, `docker`, `vscode`, `opencode`, `dsh`, `update-check`,
`virtiofs`, `cli`. Each step is implemented in `setup/steps/`.

Answers are stored in the config file and reused as defaults; a step only
prompts for the values it needs.

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
GUEST_USER="aibox"
```

### OpenCode Config

Edit `~/.config/opencode/opencode.json` in the VM to configure AI providers.

## File Structure

```
aibox/
├── aibox                        # Main CLI (VM + port forwarding + commands)
├── setup.sh                     # Setup runner (steps, with prerequisites)
├── setup/                       # Modular setup
│   ├── lib.sh                   # Step registry, prerequisites, runner
│   └── steps/                   # One script per step (vm, ssh, motd, dsh, ...)
├── cmd/                         # Command scripts
│   ├── service-add              # Add service
│   ├── service-remove           # Remove service
│   ├── service-list             # List services
│   ├── update-target            # Dispatch an update target
│   ├── check-updates            # Check for available updates
│   ├── self-update              # Pull the repo and push scripts to the VM
│   ├── vm-shutdown              # Shutdown VM
│   ├── vm-restart               # Restart VM
│   └── vm-snapshot              # Manage snapshots
├── host/                        # Host-side scripts
│   ├── create-vm.sh             # Create VM
│   ├── start-vm.sh              # Start VM
│   ├── configure-ssh.sh         # SSH setup
│   └── upload-scripts.sh        # Upload to VM
├── guest/                       # Guest-side scripts (uploaded to VM)
│   ├── install-deps.sh          # Install dependencies
│   ├── install-docker.sh        # Install Docker
│   ├── install-service.sh       # Install opencode-web service
│   ├── install-dsh.sh           # Install dsh CLI
│   ├── install-dsh-service.sh   # Install dsh-web service
│   ├── update-check.sh          # Gather available updates
│   └── install-update-check.sh  # Install the update check timer
└── shared-funcs.sh              # Common functions
```

## Security Notes

- Create a separate git account for your agents
- Never let the VM push directly to main repositories
- Keep SSH keys secure and never commit them
- Your AI should NOT have access to your secrets
