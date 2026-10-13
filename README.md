# Dev Box Setup Scripts

A collection of scripts to set up development environments with a simple runner interface.

The installer uses current upstream channels at install time: stable Rust and
Flutter, the latest Node.js release, and current package-manager releases.
Linux-specific script collections cover Debian/Ubuntu, Alpine, and the Arch
family, including CachyOS, EndeavourOS, Manjaro, Garuda, and Omarchy. Other
Linux distributions can use the common Unix scripts. Bazzite is part of the
Fedora Atomic family, so it does not use the pacman/yay scripts.

## Usage

### One-shot repository install

Run the installer directly from the repository. It downloads a temporary
Buildsmith checkout, bootstraps its build requirements, builds the runner, and
opens the interactive script selector:

```bash
curl -fsSL https://raw.githubusercontent.com/takenagain/buildsmith/main/install.sh | bash
```

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
development prerequisites. Arch-family systems have 18 Arch-specific actions
for pacman/yay, Git, Python, Node.js, Neovim, Flutter, OpenSSH, Podman,
YubiKey, Docker Engine and Desktop, Flatpak, GNOME Extension Manager, Proton
VPN, ROCm, Snap, and Bitwarden CLI. The five shared Unix actions are collected
too: `act`, JetBrains Mono Nerd Font, and `rustup` use pacman packages; Cursor
uses AUR `cursor-bin`; Toshy's upstream installer supports Arch and installs
its dependencies with pacman. Most Arch actions use repository packages.
Cursor, `snapd`, and the YubiKey agent require `yay`; Docker Desktop is
installed from Docker's official Arch package. Docker marks its Arch package
as experimental; it requires an x86_64 desktop session with virtualization.

To also install the optional AUR helper `yay`, run the installer as a normal
(non-root) user with explicit opt-in:

```bash
INSTALL_YAY=1 bash ./install.sh
```

### YubiKey SSH agent

YubiKey setup is intentionally separate from Git and OpenSSH setup. On Debian
and Arch, run the dedicated script as the desktop user:

    bash ./scripts/debian/yubikey.sh   # Debian/Ubuntu
    bash ./scripts/arch/yubikey.sh     # Arch Linux

These scripts install yubikey-agent, create the user-scoped yubikey-agent.service,
import the desktop pinentry environment, and expose the agent at
$XDG_RUNTIME_DIR/yubikey-agent/yubikey-agent.sock. The service is enabled with
systemctl --user enable --now yubikey-agent.service, so SSH PIN prompts use the
desktop session. Alpine uses its dedicated script with gpg-agent as the
server-oriented fallback:

    sh ./scripts/alpine/yubikey.sh

### Local Docker validation

Run every Linux script collected for Ubuntu, Alpine, and Arch, excluding only
the Docker setup scripts and the dedicated YubiKey setup scripts:

    make test-scripts-docker

The existing installer/build smoke test remains available separately:

```bash
make test-install-docker
docker compose -f .devcontainer/rust-compose.yml config
```

The Compose command validates the development container configuration; the
test-install-docker target runs the installer and release-runner build in each
current image.

## Project Structure

- `scripts/`: Contains setup scripts
- `runner/`: Contains the Rust runner application
- `proxmox/`: Proxmox scripts and setup guides
