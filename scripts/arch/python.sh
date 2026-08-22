#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm python python-pip python-pipx python-poetry pyenv uv

# pipx uses per-user bin, data, and state directories below ~/.local.
sudo install -d -o "$(id -u)" -g "$(id -g)" \
    "$HOME/.local" \
    "$HOME/.local/bin" \
    "$HOME/.local/share" \
    "$HOME/.local/state"
pipx ensurepath
