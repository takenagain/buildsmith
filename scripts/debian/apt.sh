#!/usr/bin/env bash

set -euo pipefail

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
if command -v snap >/dev/null 2>&1; then
    sudo snap refresh
fi

sudo apt-get install -y flatpak
if command -v flatpak >/dev/null 2>&1; then
    flatpak --user update -y
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install -y flathub io.github.zen_browser.zen
    flatpak --user install -y flathub com.mattjakeman.ExtensionManager
fi

sudo apt-get install -y \
    clang cmake curl g++ gcc git htop llvm python3 python3-pip \
    python3-venv radeontop screen tmux vim
