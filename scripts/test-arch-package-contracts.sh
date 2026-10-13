#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
arch_scripts="$repository_root/scripts/arch"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

fail() {
    printf 'Arch package contract failure: %s\n' "$1" >&2
    exit 1
}

require_script() {
    local script="$1"
    local package="$2"
    local path="$arch_scripts/$script"
    [ -f "$path" ] || fail "missing Arch action $script"
    grep -Fq "$package" "$path" || fail "$script must install or resolve $package"
}

require_script docker-engine.sh 'docker docker-compose'
grep -Fq 'systemctl enable --now docker.service' "$arch_scripts/docker-engine.sh" || \
    fail 'Docker Engine must enable docker.service'
grep -Fq 'usermod -aG docker' "$arch_scripts/docker-engine.sh" || \
    fail 'Docker Engine must add the user to the docker group'

require_script docker-desktop.sh 'docker-desktop-x86_64.pkg.tar.zst'
grep -Fq 'pacman -U' "$arch_scripts/docker-desktop.sh" || \
    fail 'Docker Desktop must install its Arch package with pacman'
grep -Fq 'systemctl --user enable docker-desktop' "$arch_scripts/docker-desktop.sh" || \
    fail 'Docker Desktop must enable its user service'

require_script flatpak.sh 'flatpak'
grep -Fq 'flatpak remote-add --system --if-not-exists flathub' "$arch_scripts/flatpak.sh" || \
    fail 'Flatpak must configure the Flathub system remote'

require_script gnome-extensions.sh 'extension-manager'
require_script protonvpn.sh 'proton-vpn-gtk-app'
require_script rocm.sh 'rocm-hip-sdk'
grep -Fq 'usermod -aG render,video' "$arch_scripts/rocm.sh" || \
    fail 'ROCm must grant the user render and video device access'

require_script snap.sh 'snapd'
grep -Fq 'yay -S' "$arch_scripts/snap.sh" || fail 'Snap must install snapd through yay'
grep -Fq 'systemctl enable --now snapd.socket' "$arch_scripts/snap.sh" || \
    fail 'Snap must enable snapd.socket'
grep -Fq '/var/lib/snapd/snap' "$arch_scripts/snap.sh" || \
    fail 'Snap must configure the /snap path'

require_script bitwarden-cli.sh 'bitwarden-cli'

# Shared Unix tools should use Arch packages when running on Arch, with the
# existing upstream installers retained as fallbacks for other Unix systems.
grep -Fq 'pacman -Syu --needed --noconfirm act' \
    "$repository_root/scripts/unix/act.sh" || fail 'act must use the official Arch package'
grep -Fq 'yay -S --needed --noconfirm cursor-bin' \
    "$repository_root/scripts/unix/cursor-ide.sh" || fail 'Cursor must use its AUR package on Arch'
grep -Fq 'pacman -Syu --needed --noconfirm ttf-jetbrains-mono-nerd' \
    "$repository_root/scripts/unix/nerd-fonts.sh" || fail 'Nerd Fonts must use the Arch package'
grep -Fq 'pacman -Syu --needed --noconfirm rustup' \
    "$repository_root/scripts/unix/rust.sh" || fail 'Rust must bootstrap rustup from pacman on Arch'

bash_path="$(command -v bash)"
if output="$(PATH="$test_root/empty-bin" "$bash_path" "$arch_scripts/snap.sh" 2>&1)"; then
    fail 'Snap must fail when yay is unavailable'
fi
case "$output" in
    *'requires yay'*|*'install yay first'*) ;;
    *) fail "Snap must explain the yay prerequisite; got: $output" ;;
esac

printf '%s\n' 'Arch package installation contracts passed.'
