# Task 5 Report: CI, devcontainer, and documentation migration

## Scope

Updated only `.github` workflows, `.devcontainer/rust-compose.yml`, `README.md`,
and `proxmox/README.md`, plus this required task report. No scripts, Cargo
files, Makefile, or `install.sh` files were changed.

## Red evidence

The required stale assertion failed before implementation. It found legacy
GitHub Actions versions, Ubuntu 22.04, Debian 11, Alpine 3.18, and macOS 13 in
the install workflow.

## Changes

- Updated workflow actions exactly to `actions/checkout@v6`,
  `actions/cache@v5`, `actions/upload-artifact@v7`,
  `actions/download-artifact@v5`, and `softprops/action-gh-release@v3`.
- Removed old fixed OS and container matrix entries, retaining current runner
  channels and Debian/Alpine `latest` images.
- Added Arch CI coverage using `archlinux:base-devel`; it initializes the
  pacman keyring and performs the required full `pacman -Syu` transaction
  before invoking the installer.
- Changed every post-install Rust verification to
  `${CARGO_HOME:-$HOME/.cargo}/bin/rustc`, so CI checks the toolchain installed
  by the script rather than relying on inherited `PATH` state.
- Changed the devcontainer Compose image to `rust:latest` and removed obsolete
  version commentary.
- Documented current-at-install stable Flutter, current Node.js LTS, current
  n8n provisioning, Arch support, opt-in non-root `INSTALL_YAY=1`, and an Arch
  Docker validation command.

## Verification

- The required stale assertion passed after the migration.
- `python3 -m json.tool .devcontainer/devcontainer.json` passed.
- PyYAML successfully parsed both GitHub workflow files and the Compose file.
- `docker compose -f .devcontainer/rust-compose.yml config` passed.
- A live `archlinux:base-devel` container completed pacman initialization,
  full upgrade/bootstrap, `bash ./install.sh`, Cargo-home Rust verification,
  and release-runner existence verification (exit status 0).
- `git diff --check` passed.

## Concerns

None. The transient Arch validation container was removed after its successful
run.
