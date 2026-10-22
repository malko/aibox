# AIBox

[![Site](https://img.shields.io/badge/site-malko.github.io%2Faibox-orange?style=flat-square)](https://malko.github.io/aibox/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Scripts for managing an AI development virtual machine with reverse proxy and service management.

**→ [malko.github.io/aibox](https://malko.github.io/aibox/)** — the project site, with the features, the network model and the quick start.

## Quick Start

```bash
# Run automated setup
./setup.sh

# Connect to VM (automatically forwards configured services)
./aibox

# Or open the local web console (services, updates, setup, VM lifecycle)
./aibox web

# Access opencode at http://localhost:4096
# (connection password: see the VM MOTD or run ./aibox status)
```

## Requirements

### Host Machine
- KVM/QEMU with libvirt
- virsh, libvirt-client installed
- BusyBox with the `httpd` applet, only for `aibox web`

```bash
sudo apt install virsh libvirt-client busybox-static
```

On macOS, install BusyBox with Homebrew:

```bash
brew install busybox
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

- binds each service on `127.0.0.1` by default: services are reachable from
  the host only, at `http://localhost:<port>`. A service can be exposed on the
  LAN independently of the others (see below);
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
| `aibox tunnel status` | Tunnel state and per-service URLs/LAN modes |
| `aibox tunnel logs` | Last tunnel logs |

### Always-on at login (optional)

If you want the service URLs to work as soon as you log in, add `aibox start`
to your desktop startup applications (GNOME/KDE "Startup Applications",
macOS "Login Items"). The VM then starts at login and the tunnel follows it.

aibox deliberately does not do this by itself: nothing runs (and no port is
open) while you are not using the VM.

### LAN exposure

LAN exposure is decided **per service**, so you can expose opencode while
keeping dsh localhost-only. Each service has one of three modes:

| Mode | How to set it | Survives reboot? |
|---|---|---|
| `localhost` | default, or `aibox tunnel lan off <service>` | — |
| temporary | `aibox tunnel lan on <service>` | No |
| permanent | `aibox tunnel lan on <service> --permanent` | Yes |

```bash
aibox tunnel lan on opencode --permanent    # always exposed
aibox tunnel lan on dsh --timeout 30m       # temporary, expires in 30 min
aibox tunnel lan on dsh --no-timeout        # temporary until reboot
aibox tunnel lan off opencode               # back to localhost
aibox tunnel lan on                         # all services, temporary
```

Temporary exposure is stored outside `services.json` in a per-boot runtime
state: it is lost at the next reboot (and may also be lost at logout when the
runtime directory is cleared), even if its timeout has not expired. Permanent
exposure is stored in `services.json` and applied again on the next
`aibox start`. `--permanent`, `--timeout` and `--no-timeout` are mutually
exclusive.

The default temporary duration is `TUNNEL_LAN_TIMEOUT` (default `2h`).
`--timeout 30m` overrides it and `--no-timeout` removes the time limit. A
per-service timer reverts the exposure automatically; the expiry is also
checked lazily on the next command and by the tunnel on startup.

`aibox service-add opencode 4096 --lan` is shorthand for adding a service with
permanent LAN exposure (`--yes` skips the confirmation prompt).
`aibox service-list` shows the mode of every service.

Before exposing, aibox checks the selected guest services for missing
authentication and warns (vscode-server without password auth). opencode
generates its own server password at startup and dsh-web connection URLs embed
an authentication token, so no warning is needed for them.

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

#### Don't forward your SSH agent into the VM

An agent forwarded over SSH is equivalent to handing the VM your credentials:
while the connection is open, anything in the VM (including agents) can ask
your local ssh-agent to sign as you, e.g. to `git push`.

- OpenSSH does not forward by default, but `ForwardAgent yes` (often set under
  `Host *` in `~/.ssh/config`) or `ssh -A` turns it on. This is the setting that
  matters: do not enable it for the VM, and scope it to specific hosts rather
  than `Host *`.
- Check from the VM: `echo $SSH_AUTH_SOCK` must be empty and `ssh-add -l` must
  fail with "Could not open a connection to your authentication agent".

## Usage

### Connect to VM

```bash
./aibox                      # Start VM + tunnel, then open a shell
./aibox 8081:80             # Also forward host 8081 to guest 80 (session only)
./aibox --lan 3000          # Ad-hoc forward exposed on the LAN
```

### Help

```bash
./aibox help                  # General help
./aibox help service-add      # Help for one command
./aibox service-add --help    # Same, from the command itself
```

### Shell completion

```bash
# Bash
./aibox --completion bash > ~/.local/share/bash-completion/completions/aibox

# Zsh (add ~/.zsh/completions to fpath)
./aibox --completion zsh > ~/.zsh/completions/_aibox
```

Completion covers commands, options, tunnel/LAN subcommands, configured
services for `service-remove` and `tunnel lan on/off`, snapshot names for
`snapshot delete/revert`, setup steps and update targets.

### Start / status

```bash
./aibox start                 # Start VM + tunnel without opening a shell
./aibox status                # VM state, service URLs, tunnel state
./aibox shutdown              # Stop tunnel + shutdown VM
./aibox restart               # Restart VM (tunnel reconnects automatically)
```

`aibox status` also reports whether each service port is listening in the VM: a
green dot when the service answers, a red dot when it does not. The check runs
inside the VM, because the host port always accepts connections while the
tunnel is up, even when the guest service is down. When the output is
redirected, the dot is replaced by the state as text (`[up]`, `[down]`,
`[unknown]`).

### Web interface

`aibox web` starts a local web console and opens it in your browser:

```bash
./aibox web
./aibox web --port 8788
./aibox web --no-open
```

It listens on `127.0.0.1` only and requires BusyBox with the `httpd` applet.
The server runs in the foreground: press `Ctrl+C` to stop it, or use the
**close / fermer** button in the header. Closing the browser tab also stops it
after a short grace period; a reload cancels that delayed stop. Nothing keeps
running in the background.

The console provides:

- VM lifecycle: start, restart, shutdown (with optional force);
- tunnel state and controls;
- service list, add/edit/remove, per-service LAN exposure and links;
- update check and a multi-target update selection; OS updates ask for the
  guest sudo password, which is transmitted through pipes and never written to
  disk;
- setup status detection and replay of safe setup steps; steps that need root
  ask for the same sudo password;
- running operations show their log and can be killed from the console;
- LAN hostname setting for service URLs;
- interface language: English (default) or French;
- a live availability indicator per service: a green dot when the port is
  listening in the VM, a red dot when it is closed;
- a snapshots section: list, create, revert and delete the VM snapshots;
- a button opening a terminal window connected to the VM (it runs `aibox -n`:
  a plain SSH session, without port forwarding).

The interface language is selected in the **réglages / settings** section and
is remembered in the browser (`localStorage`). The default is English.

The access token is generated at every start, in the runtime directory
(`${XDG_RUNTIME_DIR}/aibox-web.token`, mode `600`), and is passed to the
browser in the URL fragment. The API requires it as a bearer token, rejects
non-local `Host`/`Origin` headers, and never listens on the LAN. When the
configured port is busy, the console takes the next free one. Keys `1`–`6`
switch between the console sections.

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
./aibox tunnel status                 # Tunnel state, per-service URLs and LAN modes
./aibox tunnel start                  # Start the tunnel (VM keeps running)
./aibox tunnel stop                   # Stop the tunnel (VM keeps running)
./aibox tunnel lan on opencode --permanent   # Permanently expose one service
./aibox tunnel lan on dsh --timeout 30m      # Temporary exposure (30 min)
./aibox tunnel lan on dsh --no-timeout       # Temporary until reboot
./aibox tunnel lan off opencode              # Back to localhost for one service
./aibox tunnel lan off                       # Back to localhost for all services
./aibox tunnel install                # Install the user service
./aibox tunnel uninstall              # Remove the user service
./aibox tunnel logs                   # Last tunnel logs
```

### VS Code (Remote-SSH)

Use your local VS Code on the VM over SSH, without keeping a session open:

```bash
./aibox vscode                 # Open the current directory when it is shared
./aibox vscode ~/git/aibox     # Open a specific directory from the share
./aibox vscode --guest-path /var/log   # Open a path inside the VM
```

`aibox vscode` resolves the VM address on the fly and runs
`code --remote ssh-remote+<user>@<ip> <dir>`, so nothing is written to
`~/.ssh/config`. Requirements on the host: the `code` CLI (VS Code:
"Shell Command: Install 'code' command in PATH") and the **Remote - SSH**
extension. The VS Code Server is installed automatically inside the VM on
first connection.

Notes:
- Only paths under the shared host directory (`HOST_SHARE_DIR`, default
  `~/git`) are mapped automatically: the host path is resolved (symlinks
  included) and turned into its path in the VM, where the share is mounted.
  A path outside of it is refused, with `--guest-path` as the way to open a
  path that only exists in the VM.
- With no argument, the current directory is used when it is inside the
  share. Otherwise aibox shows an error and asks for a directory to open
  (or lets you quit).
- `--guest-path` opens a path inside the VM: an absolute path (`/var/log`),
  a path starting with `~` (`~/git/repo`) or a path relative to the shared
  directory (`repo`). The path must exist in the VM.
- The host key is accepted automatically (no fingerprint prompt).
- On macOS/Lima the Reachable address is the Lima instance (`lima-<name>`);
  add `Include ~/.lima/*/ssh.config` to `~/.ssh/config` once.

### Service Management

```bash
./aibox service-add opencode 4096            # Add a service (localhost only)
./aibox service-add portainer 8080:9000      # Add with custom port mapping
./aibox service-add opencode 4096 --lan      # Add with permanent LAN exposure
./aibox service-edit opencode --port 4097    # Change the port
./aibox service-edit opencode --name oc --lan # Rename and expose on the LAN
./aibox service-list                         # List services and LAN modes
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
./aibox snapshot list --json         # Same, machine-readable
./aibox snapshot delete my-snap     # Delete snapshot
./aibox snapshot revert my-snap     # Revert to snapshot
./aibox snapshot revert my-snap --yes --start  # Revert, then start the VM again

Note: Snapshots are internal (embedded in qcow2 file). VM must be shut off to create.
`--yes` skips the confirmation and shuts the VM down first, `--start` restarts it
after a create or a revert.

The web console opens a terminal window running `aibox -n`: a plain SSH
session, with no port forwarding and without touching the tunnel service. The
emulator is picked automatically: the well known ones (`kitty`, `alacritty`,
`wezterm`, `foot`, `gnome-terminal`, `konsole`, `xfce4-terminal`,
`x-terminal-emulator`, `xterm`) first, then the default terminal of the desktop
environment (`xdg-terminal-exec`, the freedesktop default terminal
specification), then a generated desktop entry and finally Terminal.app on
macOS. Set `AIBOX_TERMINAL` to force one:

```bash
AIBOX_TERMINAL=wezterm ./aibox web   # always use wezterm
AIBOX_TERMINAL=xdg-terminal-exec ./aibox web
```
```

### Updates

```bash
./aibox update scripts            # Upload the latest scripts to the VM
./aibox update os                 # apt update + dist-upgrade (interactive)
./aibox update os -y              # Same, non-interactive
./aibox update opencode           # Update opencode (opencode update) + restart server
./aibox update dsh                # Update dsh + restart dsh-web
./aibox update claude             # Update Claude Code
./aibox update vscode-server      # Pull and restart vscode-server
./aibox update all                # scripts, os, opencode, dsh, claude, vscode-server
./aibox check-updates             # Check for updates (aibox repo + VM)
./aibox self-update               # Pull the aibox repo and push scripts to the VM
```

`all` stops at the first failure. `opencode-service` is excluded (it only
reinstalls the opencode service).

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
./setup.sh --status           # Show what is installed
./setup.sh --status --json    # Same, machine-readable
./setup.sh motd --yes         # Use saved/default answers (non-interactive)
./setup.sh motd --no-deps     # Run only this step, without prerequisites
./setup.sh --help             # List all steps
```

Steps (in order): `vm`, `ssh`, `scripts`, `deps`, `sshd`, `git`, `dirs`,
`hosts`, `motd`, `docker`, `vscode`, `opencode`, `dsh`, `claude`, `update-check`,
`virtiofs`, `cli`, `tunnel`. Each step is implemented in `setup/steps/`.

The `cli` step is host-only: it links `aibox` into `~/.local/bin`, adds it to
`PATH` only when the command cannot be found already, and installs bash/zsh
completion. It does not modify the VM and does not need root.

The `motd` step installs the login banner in the VM. It shows the services it
knows about with a coloured dot: green when the service answers on its port,
red when the unit runs but the port is closed, dim when the service is
installed but not running. Re-run the step to update an installed banner:

```bash
./setup.sh motd
```

Answers are stored in the config file and reused as defaults; a step only
prompts for the values it needs.

## Configuration

### Services Config

Services are stored in `~/.config/aibox/services.json`:

```json
{
  "opencode": { "port": "4096", "lan": "permanent" },
  "dsh": { "port": "3080" },
  "portainer": { "port": "8080:9000" }
}
```

- `port` is the guest port, or `<host_port>:<guest_port>`.
- `lan: "permanent"` exposes the service on the LAN and survives reboots.
- Without `lan`, the service is localhost-only. Temporary LAN exposure is not
  stored here: it lives in a per-boot runtime file and disappears at reboot.

Legacy string entries (`"opencode": "4096"`) are still read and normalized to
the object format on the next change.

### AIBox Config

Main config is at `~/.config/aibox/aibox.conf`:

```
VM_NAME="ai-agentbox"
GUEST_USER="aibox"
```

Tunnel settings:

```
TUNNEL_LAN_TIMEOUT="2h"      # default temporary LAN duration
TUNNEL_WAIT="120"            # seconds the tunnel waits for the VM
```

Web interface settings:

```
LAN_HOSTNAME="desk.local"    # hostname used in LAN service URLs (empty = auto)
WEB_PORT="8787"              # local web console port
```

`TUNNEL_BIND` was the old global LAN switch. It is migrated automatically to
per-service settings on the next aibox command; it is no longer needed.

### OpenCode Config

Edit `~/.config/opencode/opencode.json` in the VM to configure AI providers.

`opencode serve` generates its own connection password at startup (it changes
on every restart). The VM MOTD and `aibox status` display the current one.

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
│   ├── service-add              # Add service (optional permanent LAN)
│   ├── service-edit             # Edit or rename a service
│   ├── service-remove           # Remove service
│   ├── service-list             # List services and LAN modes
│   ├── web                      # Local web console (BusyBox httpd)
│   ├── config                   # Read or update aibox.conf
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
│   ├── install-service.sh       # Install the opencode serve service
│   ├── install-dsh.sh           # Install dsh CLI
│   ├── install-dsh-service.sh   # Install dsh-web service
│   ├── install-claude.sh        # Install Claude Code
│   ├── update-check.sh          # Gather available updates
│   └── install-update-check.sh  # Install the update check timer
├── web/                         # Local web console
│   ├── public/                  # HTML/CSS/JS and BusyBox CGI (i18n.js = translations)
│   └── lib/                     # CGI helpers, job runner and open-terminal.sh
├── services-funcs.sh            # services.json + per-service LAN state
└── shared-funcs.sh              # Common functions
```

## Security Notes

- Services are exposed on localhost only by default; use
  `aibox tunnel lan on <service>` for temporary access, or
  `aibox tunnel lan on <service> --permanent` only when you really need it
- Permanent exposure survives reboots; review it with `aibox service-list` and
  turn it off with `aibox tunnel lan off <service>` when it is no longer needed
- The web console listens on `127.0.0.1` only and requires a local token;
  do not expose it on the LAN. Use an SSH port forward if you need remote access
- opencode generates its own server password at startup; vscode-server should
  keep a password; aibox warns before LAN exposure when they are unprotected
- The host `~/git` share is writable by design: the agent can modify your
  working copies, so review changes and push from the host
- Create a separate git account for your agents
- Never let the VM push directly to main repositories
- Keep SSH keys secure and never commit them
- Your AI should NOT have access to your secrets
