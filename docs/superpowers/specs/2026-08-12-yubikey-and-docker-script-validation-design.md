# YubiKey Agent Separation and Linux Script Validation Design

## Goal

Separate YubiKey provisioning from Git/OpenSSH and SSH-server setup, use a
systemd user-scoped `yubikey-agent` on Debian and Arch with the session socket
and pin-entry environment expected by this host, retain Alpine's `gpg-agent`
fallback, and execute every collected Ubuntu, Alpine, and Arch installer
script in disposable Docker containers except Docker and YubiKey scripts.

## Design

Each supported OS receives a dedicated `yubikey` script. The existing `git`
scripts install Git/OpenSSH client tooling and configure Git signing, but do
not install or start a YubiKey agent. SSH server scripts remain responsible
only for `sshd`, firewall, authorized keys, and server policy.

On Debian and Arch, `yubikey.sh` installs `yubikey-agent`, pinentry, PC/SC,
and smart-card support; writes an idempotent user unit to
`~/.config/systemd/user/yubikey-agent.service`; and starts it with
`systemctl --user enable --now`. The unit uses `%t/yubikey-agent/` for its
runtime socket, `RuntimeDirectory=yubikey-agent`, a resolved absolute
`yubikey-agent` executable, and the existing hardening settings. The script
exports the same socket through the user's shell profile and imports the
session's display, Wayland, D-Bus, and SSH-agent variables into the user
manager so graphical pinentry dialogs continue to work.

Alpine's separate `yubikey.sh` configures `gpg-agent` SSH support and
pinentry, because Alpine is a server-oriented fallback environment. macOS and
Windows also receive separate YubiKey scripts so their existing platform
agent setup is no longer hidden inside Git setup.

The Rust runner gains a non-interactive `run-all` command with repeatable
relative-path exclusions. The Docker harness creates a disposable non-root
user with passwordless sudo, builds the runner, and invokes `run-all` with only
`docker` and `yubikey` paths excluded. Scripts use `CI=1` and explicit test
SSH inputs where prompts otherwise require a human. A failing script fails
the container and reports its path.

## Error handling and safety

- Unit and profile writes are idempotent and preserve existing user content.
- YubiKey scripts fail clearly when their required agent/systemd facilities
  are unavailable; Docker validation excludes them because no hardware or
  graphical pinentry is available.
- Docker validation never mounts the repository writable and uses disposable
  Cargo, Rustup, and build directories.
- Docker and YubiKey exclusions are path-based and printed by the harness;
  no other script is skipped.
- SSH-server scripts accept `SSH_PUBLIC_KEY` and `SSH_PORT` in CI, while
  retaining interactive prompts for normal use.

## Verification

1. Contract tests fail before the new YubiKey files and runner command exist.
2. Rust tests, formatting, and Clippy pass.
3. Every modified shell script passes syntax validation.
4. Fresh Docker runs pass for `ubuntu:latest`, `alpine:latest`, and
   `archlinux:base`, with all non-excluded collected scripts executed.
5. Static checks confirm Git/SSH scripts no longer own YubiKey setup and
   Debian/Arch units are user-scoped with the expected runtime socket.
