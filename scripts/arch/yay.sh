#!/usr/bin/env bash

set -euo pipefail

if [ "${INSTALL_YAY:-}" != "1" ]; then
    echo "yay installation is opt-in; rerun with INSTALL_YAY=1." >&2
    exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "yay must be built as a non-root user; do not run this script as root." >&2
    exit 1
fi

sudo pacman -Syu --needed --noconfirm base-devel git

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
cd "$build_dir/yay"
makepkg -si --noconfirm --needed
