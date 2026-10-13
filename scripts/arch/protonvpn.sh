#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm proton-vpn-gtk-app networkmanager gnome-keyring

echo "Proton VPN is installed. Its desktop app requires NetworkManager and a Secret Service keyring; check that NetworkManager is active before connecting."
