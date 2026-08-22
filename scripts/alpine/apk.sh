#!/bin/sh

set -eu

sudo apk update
sudo apk upgrade
sudo apk add --no-cache \
    htop curl git python3 py3-pip gcc g++ cmake clang llvm \
    screen tmux vim go remmina firefox-esr telegram-desktop

echo "Run the Alpine Node.js setup to install Bitwarden CLI with its supported runtime."
echo "Alpine does not provide Flatpak/Snap desktop applications in the base repositories."
