#!/usr/bin/env bash

set -euo pipefail

sudo apt-get update
sudo apt-get install -y fd-find git neovim python3-dev python3-pip

mkdir -p "$HOME/.config"
if [ ! -d "$HOME/.config/nvim/.git" ]; then
    git clone https://github.com/takenagain/nvchad-config.git "$HOME/.config/nvim"
fi
