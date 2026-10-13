#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm flatpak
sudo flatpak remote-add --system --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
