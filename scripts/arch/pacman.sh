#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    pacman -Syu --needed --noconfirm base-devel ca-certificates curl git sudo
else
    sudo pacman -Syu --needed --noconfirm base-devel ca-certificates curl git sudo
fi
