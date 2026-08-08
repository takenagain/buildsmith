# Dev Box Setup Scripts

A collection of scripts to set up development environments with a simple runner interface.

The installer uses current upstream channels at install time: stable Rust and
Flutter, the current Node.js LTS, and current package-manager releases.
Supported Linux distributions include Debian/Ubuntu, Alpine, Red Hat-family
systems, and Arch Linux.

## Usage

### Interactive Mode

Run all scripts in interactive mode:

```bash
make install
```

### Run Specific Scripts

Run a specific script (e.g., to install nodejs):

```bash
make install-nodejs
```

### List Available Scripts

List all available scripts:

```bash
make list-scripts
```

### Additional Commands

```bash
make install-deps  # Install system dependencies
make build        # Build the runner
make run-scripts  # Run specified scripts (use SCRIPTS variable)
make clean        # Clean build artifacts
make deps         # Update dependencies
make test         # Run tests
make fmt         # Format code
make fmt-check   # Check code formatting
make lint        # Run linter
```

### Arch Linux and yay

Arch bootstrap uses a full `pacman -Syu` upgrade and installs the standard
development prerequisites. To also install the optional AUR helper `yay`, run
the installer as a normal (non-root) user with explicit opt-in:

```bash
INSTALL_YAY=1 bash ./install.sh
```

### Local Docker validation

Validate the installer against current Debian, Alpine, and Arch Linux images:

```bash
docker compose -f .devcontainer/rust-compose.yml config
docker run --rm -e CI=1 -v "$PWD":/workspace -w /workspace archlinux:base-devel \
  bash -euxo pipefail -c 'pacman-key --init; pacman -Syu --needed --noconfirm curl ca-certificates git sudo bash make; bash ./install.sh; "${CARGO_HOME:-$HOME/.cargo}/bin/rustc" --version'
```

## Project Structure

- `scripts/`: Contains setup scripts
- `runner/`: Contains the Rust runner application
- `proxmox/`: Proxmox scripts and setup guides
