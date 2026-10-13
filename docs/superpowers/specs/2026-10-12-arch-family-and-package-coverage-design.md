# Arch Family and Package Coverage Design

## Goal

Make Buildsmith select Arch scripts on CachyOS and other Arch-derived distributions, expose the Linux setup actions that currently lack Arch counterparts, and refresh stale package and tool pins across supported distributions.

## Context

The runner currently selects the `arch` script directory only when `os_info` reports the exact Arch type. CachyOS identifies itself with `ID=cachyos` and `ID_LIKE=arch`, so it receives only the five common Unix scripts. The bootstrap installer and Makefile also rely on `/etc/arch-release` or the exact `ID=arch` value.

The project already has Arch implementations for Flutter, Git, Neovim, Node.js, OpenSSH, Pacman, Podman, Python, yay, and YubiKey. Debian-only Linux actions without Arch counterparts are Docker Engine, Docker Desktop, Flatpak, GNOME extensions, Proton VPN, ROCm, and Snap. Alpine's Node.js action also bundles Bitwarden CLI, which has a native Arch package and should be exposed as a separate Arch action.

## Distro Detection

Use the standard `/etc/os-release` `ID` and `ID_LIKE` fields to identify the package family. Parse `ID_LIKE` as whitespace-separated exact tokens and route systems whose ID or ID_LIKE contains `arch` to the existing `scripts/arch` directory. Keep the existing `os_info` mapping as a fallback for systems without readable os-release metadata.

Apply the same Arch-family check in the Rust runner, `install.sh`, and `make install-deps`. Add fixture coverage for CachyOS, EndeavourOS, Manjaro, Garuda, and Omarchy metadata, and verify that Fedora-family metadata does not select Arch scripts.

Bazzite is a Fedora Atomic image, not an Arch derivative. Do not select pacman/yay scripts for Bazzite; supporting it requires a separate Fedora Atomic implementation.

## Arch Package Coverage

Add Arch scripts for the Linux actions that currently have no Arch counterpart:

- Docker Engine, using Arch packages and systemd service setup.
- Docker Desktop, installing Docker's Arch package with `pacman`.
- Flatpak, using the Arch package and the existing Flathub setup flow.
- GNOME extensions, using the Arch GNOME extension manager package.
- Proton VPN, using the Arch `proton-vpn-gtk-app` package.
- ROCm, using Arch's ROCm packages and the corresponding runtime/device access setup.
- Snap, installing `snapd` through `yay` and configuring its socket.
- Bitwarden CLI, using the native Arch `bitwarden-cli` package.

Keep the current common Unix scripts available for Arch-family systems. Do not add Fedora or Bazzite package support in this change.

Where a common Unix action has an Arch package, use that package on Arch-family
systems: `act`, `ttf-jetbrains-mono-nerd`, and `rustup` use pacman; Cursor uses
the AUR `cursor-bin` package through yay. Toshy's upstream installer supports
Arch and resolves its dependencies through pacman, so it remains on the shared
Unix path.

## Version Refresh

Refresh confirmed stale values and their tests, fixtures, lockfiles, and wrapper references:

- NVM `0.40.7` to `0.40.8` in Debian and Alpine installers.
- Bitwarden CLI `2026.8.0` to `2026.9.1`; use the supported Node 24 LTS runtime and matching npm 11 runtime in Alpine, then regenerate the integrity-locked package metadata inside Podman.
- AMDGPU installer `31.40.1` to `31.60`, including the upstream package filename.
- Update `runner/Cargo.lock` only where compatible dependencies have newer published versions.

Check the Android SDK package list and the Proton VPN repository package in a Podman container before deciding whether their current pins need changes. Keep CI distro tags on their current moving channels unless the audit finds a stale explicit release pin.

## Validation

- Rust tests cover exact-token `ID`/`ID_LIKE` family detection and collection of Arch scripts for CachyOS fixtures.
- Shell contract tests cover the shared Arch-family bootstrap predicate and the new Arch package script commands.
- Run the Rust and shell test suites in Podman containers only.
- Use disposable Arch and Alpine Podman containers for package/version checks and installation validation. Preserve base images and remove task-created containers, volumes, and build cache afterward.
- Update README coverage text to describe supported Linux families accurately and identify Bazzite as outside the Arch family.

## Research Sources

- [systemd os-release specification](https://www.freedesktop.org/software/systemd/man/latest/os-release.html) defines `ID_LIKE` as a space-separated list of related package and programming-interface identifiers.
- [CachyOS](https://cachyos.org/), [EndeavourOS](https://endeavouros.com/), [Manjaro](https://wiki.manjaro.org/index.php?title=Manjaro%3AA_Different_Kind_of_Beast%2Fen), and [Omarchy](https://omarchy.org/manual/) identify themselves as Arch based or Arch compatible.
- [Bazzite documentation](https://docs.bazzite.gg/General/Fedora_Atomic_Comparison/) identifies Bazzite as a Fedora Atomic image.
- [Arch package database](https://archlinux.org/packages/extra/any/proton-vpn-gtk-app/), [Docker Arch install instructions](https://docs.docker.com/desktop/setup/install/linux/archlinux/), [Arch ROCm package](https://archlinux.org/packages/extra/any/rocm-hip-sdk/), and [Arch Snap guidance](https://wiki.archlinux.org/title/Snap) confirm package paths for the missing Arch actions.
- Current version references: [NVM releases](https://github.com/nvm-sh/nvm/releases), [Bitwarden CLI releases](https://github.com/bitwarden/clients/releases), [Node 24.21.0 archive](https://nodejs.org/en/download/archive/v24.21.0), and [AMDGPU 31.60 repository](https://repo.radeon.com/amdgpu-install/31.60/ubuntu/).
