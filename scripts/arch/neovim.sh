#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm neovim python-pynvim fd git
mkdir -p "$HOME/.config"
if [ ! -d "$HOME/.config/nvim/.git" ]; then
    git clone https://github.com/takenagain/nvchad-config.git "$HOME/.config/nvim"
fi
