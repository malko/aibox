# AGENTS.md - Guidelines for AI Agents

This repository contains bash scripts for managing an AI development VM and integrating with LM Studio.

## Project Overview

- **Type**: Bash scripts collection (no build system, no tests)
- **Main Scripts**:
  - `aibox.sh` - KVM/QEMU VM management with SSH port forwarding
  - `update-opencode-models.sh` - Sync LM Studio models to opencode config
  - `service_install.sh` - Install opencode-web as systemd user service

## Commands

### Running Scripts

```bash
# Make executable if needed
chmod +x script-name.sh

# Run aibox (VM + port forwarding)
./aibox.sh [host_port:guest_port] [port] ...
./aibox.sh 8081:80 3000

# Update opencode models from LM Studio
./update-opencode-models.sh

# Install opencode-web service
./service_install.sh
```

### Linting

Use shellcheck for bash linting:

```bash
# Install shellcheck
sudo apt install shellcheck

# Lint a specific script
shellcheck script-name.sh

# Lint all scripts
shellcheck *.sh
```

### Syntax Check

```bash
# Check bash syntax without executing
bash -n script-name.sh

# Check all scripts
for f in *.sh; do bash -n "$f"; done
```

## Code Style Guidelines

### Shebang and Headers

- Use `#!/bin/bash` (not `/bin/sh` - this repo uses bash-specific features)
- Include descriptive comments for complex scripts
- Document usage in the script or via `--help` / `-h` flags

### Variables

- Use UPPER_CASE for constants/config (e.g., `VM_NAME`, `CONFIG_PATH`)
- Use lower_case for local variables inside functions
- Always quote variables: `"$VAR"` not `$VAR`
- Use `${VAR}` for clarity or when concatenating: `${VAR}_suffix`

```bash
# Good
CONFIG_PATH="${HOME}/.config/opencode/opencode.json"
local temp_file="$TEMP_DIR/output.txt"

# Avoid
CONFIG_PATH=$HOME/.config/opencode/opencode.json
temp_file=$TEMP_DIR/output.txt
```

### Functions

- Use `function_name()` or `function function_name` syntax (consistent within file)
- Declare local variables with `local`
- Use `set -e` at script start for error handling (when appropriate)

```bash
# Good
fetch_lms_models() {
    local url="$1"
    local response_file="$TEMP_DIR/response.json"
    
    if ! curl -s "$url" > "$response_file"; then
        echo "Error: failed to fetch" >&2
        return 1
    fi
}
```

### Conditionals

- Use `[[ ]]` for bash (not `[ ]`)
- Quote strings when comparing: `[[ "$VAR" == "value" ]]`
- Use `-z` / `-n` for empty/non-empty checks

```bash
# Good
if [[ -z "$GUEST_IP" ]]; then
    echo "Error: no IP detected"
    exit 1
fi

# Avoid
if [ -z $GUEST_IP ]; then
```

### Error Handling

- Use `set -e` for scripts that should exit on first error
- Use `set -o pipefail` for pipelines where exit code matters
- Redirect errors to stderr: `echo "message" >&2`
- Always `exit 1` on failure in main logic

```bash
set -e
set -o pipefail

if ! command -v virsh &>/dev/null; then
    echo "Error: virsh not found" >&2
    exit 1
fi
```

### Colors and Output

- Use ANSI colors for user-facing output
- Define colors at the top of the script

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

echo -e "${GREEN}✅ Success${NC}"
echo -e "${RED}❌ Error${NC}" >&2
```

### String Manipulation

- Use parameter expansion when possible over external commands
- Use `$(command)` over backticks `` `command` ``

```bash
# Good
HOST_PORT="${ARG%%:*}"
GUEST_PORT="${ARG#*:}"

# Avoid
HOST_PORT=$(echo "$ARG" | cut -d: -f1)
```

### Arrays and Loops

- Use proper bash arrays for lists
- Always quote array expansions: `"${array[@]}"`

```bash
# Good
FORWARD_ARGS=""
for ARG in "$@"; do
    FORWARD_ARGS="$FORWARD_ARGS -L $ARG"
done

# Avoid (loses empty elements)
for ARG in $@; do
```

### External Commands

- Check if command exists before using: `command -v foo`
- Use `--quiet` / `--silent` flags when appropriate
- Always set timeouts for network calls

```bash
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required" >&2
    exit 1
fi

curl -s --max-time 10 "$url"
```

### Temporary Files

- Use `mktemp -d` for directories, `mktemp` for files
- Always clean up with traps

```bash
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
```

### Portability

- Avoid GNU-specific flags when possible
- Use POSIX-compatible constructs for maximum portability
- Test on multiple shells if portability matters

## File Naming

- Use lowercase with hyphens: `script-name.sh`
- Add `.sh` extension to shell scripts

## Git Conventions

- Use gitmoji for commits: ✨ (feat), 🔧 (fix), 📝 (docs), ♻️ (refactor)
- Write descriptive commit messages
- Keep commits atomic and focused

## Importing / Sourcing

This repo has no shared library files. If adding one:
- Use `source` or `.` to import
- Check file exists before sourcing
- Use absolute paths or paths relative to script location

## Testing

There are no automated tests for this bash scripts project. Manual testing:

```bash
# Syntax check
bash -n script.sh

# Lint
shellcheck script.sh

# Dry run (if supported)
./script.sh --dry-run
```

## Common Dependencies

- `virsh` - for KVM/QEMU VM management
- `jq` - for JSON parsing
- `curl` - for HTTP requests
- `nc` (netcat) - for network checks
- `systemctl` - for systemd user services
- `loginctl` - for linger management
