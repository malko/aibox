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
on the guest's localhost (`127.0.0.1`), and the host only exposes them through
an authenticated SSH tunnel managed as a user service.

### Tunnel service

`aibox tunnel install` (or the `tunnel` setup step) installs a user service
(`systemd --user` on Linux, LaunchAgent on macOS) that keeps one SSH tunnel
open per configured service. It:

- binds on `127.0.0.1` by default: services are reachable from the host only,
  at `http://localhost:<port>`;
- waits for the VM (`TUNNEL_WAIT`, 120s) when it is off, then stops cleanly:
  no polling and no resource use while the VM is down;
- reconnects by itself after a VM restart (the restart drops the SSH
  connection, the service re-establishes it);
- never starts the VM: starting the VM through aibox (`aibox start`, `aibox`,
  `aibox restart`) starts the tunnel with it;
- is not started at login, so nothing runs while the VM is off.

### Lifecycle

| Command | Effect |
|---|---|
| `aibox start` | Start the VM and the tunnel service (no shell) |
| `aibox` | Start the VM + tunnel, then open a shell (ad-hoc ports only) |
| `aibox status` | VM state, service URLs and tunnel state |
| `aibox shutdown` | Stop the tunnel service, then shut the VM down |
| `aibox restart` | Restart the VM; the tunnel reconnects automatically |
| `aibox tunnel start/stop/restart` | Control the tunnel without touching the VM |
| `aibox tunnel status` | Tunnel state, bind mode and URLs |
| `aibox tunnel logs` | Last tunnel logs |

### Always-on at login (optional)

If you want the service URLs to work as soon as you log in, add `aibox start`
to your desktop startup applications (GNOME/KDE "Startup Applications",
macOS "Login Items"). The VM then starts at login and the tunnel follows it.

aibox deliberately does not do this by itself: nothing runs (and no port is
open) while you are not using the VM.

### LAN exposure

`aibox tunnel lan on` rebinds the tunnels on `0.0.0.0`, making the services
reachable from the LAN at `http://<hostname>.local:<port>`. Before exposing,
aibox checks the guest for unauthenticated services and warns (opencode-web
without a password, vscode-server without password auth). dsh-web connection
URLs embed an authentication token, so no warning is needed.

The exposure is time-limited: it reverts to localhost after
`TUNNEL_LAN_TIMEOUT` (default `2h`). `--timeout 30m` overrides it,
`--no-timeout` (or `--timeout 0`) disables the automatic revert, and
`aibox tunnel lan off` turns it off immediately. The expiry survives reboots
(it is checked lazily on the next command).

### Ad-hoc ports

`aibox 8081:80` forwards an extra port inside the SSH session only. It binds
to localhost unless `--lan` is given, and disappears when the session ends.
Ad-hoc ports are for throwaway use; configured services belong in
`services.json` and are handled by the tunnel service.

### Host share

Host `~/git` is deliberately mounted writable inside the VM so agents work
directly on your repositories. This is a conscious trade-off: the agent can
modify your working copies, so keep pushes manual from the host and never put
repository credentials inside the VM.

## Usage

### Connect to VM

```bash
./aibox                      # Start VM + tunnel, then open a shell
./aibox 8081:80             # Also forward host 8081 to guest 80 (session only)
./aibox --lan 3000          # Ad-hoc forward exposed on the LAN
./aibox -w                   # Open the browser for the first service
```

### Start / status

```bash
./aibox start                 # Start VM + tunnel without opening a shell
./aibox status                # VM state, service URLs, tunnel state
./aibox shutdown              # Stop tunnel + shutdown VM
./aibox restart               # Restart VM (tunnel reconnects automatically)
```

### Run a command in the VM

`aibox exec` runs a command inside the VM over SSH and returns its exit code.
It is meant for scripting: stdout/stderr/stdin pass through unchanged and
nothing else is printed, so it composes well in pipelines.

```bash
./aibox exec uname -a                       # run a command
./aibox exec echo "hello world"             # arguments keep their boundaries
./aibox exec bash -lc 'cd ~/git/repo && make'  # shell features via a shell
printf 'data' | ./aibox exec cat            # stdin is forwarded
./aibox exec -t htop                         # allocate a TTY for interactive tools

if ./aibox exec test -f /etc/os-release; then ...   # exit code propagates
```

The VM must be running (start it with `./aibox start`); otherwise `exec` fails
immediately with a non-zero status.

### Tunnel management

```bash
./aibox tunnel status                 # Tunnel state, bind mode, URLs
./aibox tunnel start                  # Start the tunnel (VM keeps running)
./aibox tunnel stop                   # Stop the tunnel (VM keeps running)
./aibox tunnel lan on                 # Expose services on the LAN (2h by default)
./aibox tunnel lan on --timeout 30m   # ... for 30 minutes
./aibox tunnel lan off                # Back to localhost only
./aibox tunnel install                # Install the user service
./aibox tunnel uninstall              # Remove the user service
./aibox tunnel logs                   # Last tunnel logs
```

### VS Code (Remote-SSH)

Use your local VS Code on the VM over SSH, without keeping a session open:

```bash
./aibox vscode                 # Open the shared ~/git directory in the VM
./aibox vscode ~/git/aibox     # Open a specific directory from the share
```

`aibox vscode` resolves the VM address on the fly and runs
`code --remote ssh-remote+<user>@<ip> <dir>`, so nothing is written to
`~/.ssh/config`. Requirements on the host: the `code` CLI (VS Code:
"Shell Command: Install 'code' command in PATH") and the **Remote - SSH**
extension. The VS Code Server is installed automatically inside the VM on
first connection.

Notes:
- Only directories under the shared host directory (`HOST_SHARE_DIR`, default
  `~/git`) are mapped automatically. For any other path, aibox shows an error
  and asks for the target path inside the VM (or lets you quit). The typed path
  may be absolute (`/var/log`), start with `~` (`~/git/repo`) or be relative to
  the shared directory (`repo`).
- The host key is accepted automatically (no fingerprint prompt).
- On macOS/Lima the Reachable address is the Lima instance (`lima-<name>`);
  add `Include ~/.lima/*/ssh.config` to `~/.ssh/config` once.

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
./aibox update claude             # Update Claude Code
./aibox update vscode-server      # Pull and restart vscode-server
./aibox update all                # scripts, os, opencode, dsh, claude, vscode-server
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
`hosts`, `motd`, `docker`, `vscode`, `opencode`, `dsh`, `claude`, `update-check`,
`virtiofs`, `cli`, `tunnel`. Each step is implemented in `setup/steps/`.

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

Tunnel settings:

```
TUNNEL_BIND="local"          # "local" (127.0.0.1) or "lan" (0.0.0.0)
TUNNEL_LAN_TIMEOUT="2h"      # default 'lan on' auto-revert delay
TUNNEL_WAIT="120"            # seconds the tunnel waits for the VM
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
│   ├── start                    # Start VM + tunnel (no shell)
│   ├── status                   # VM state, URLs, tunnel state
│   ├── tunnel                   # Manage the tunnel user service
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
│   ├── tunnel.sh                # Tunnel service entry point (ssh -N -L)
│   ├── service.sh               # Service manager selection
│   ├── services/                # systemd --user / launchd implementations
│   ├── vm.sh                    # VM helpers (libvirt)
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
│   ├── install-claude.sh        # Install Claude Code
│   ├── update-check.sh          # Gather available updates
│   └── install-update-check.sh  # Install the update check timer
└── shared-funcs.sh              # Common functions
```

## Security Notes

- Services are exposed on localhost only by default; use `aibox tunnel lan on`
  (time-limited) when you really need LAN access
- opencode-web and vscode-server should keep a password; aibox warns before
  LAN exposure when they do not
- The host `~/git` share is writable by design: the agent can modify your
  working copies, so review changes and push from the host
- Create a separate git account for your agents
- Never let the VM push directly to main repositories
- Keep SSH keys secure and never commit them
- Your AI should NOT have access to your secrets
