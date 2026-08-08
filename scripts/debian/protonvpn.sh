#!/bin/bash

set -euo pipefail

deb_file="$(mktemp --suffix=.deb)"
trap 'rm -f "$deb_file"' EXIT
wget -q -O "$deb_file" https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb
echo "0b14e71586b22e498eb20926c48c7b434b751149b1f2af9902ef1cfe6b03e180  $deb_file" | sha256sum --check -
sudo apt install -y "$deb_file"
sudo apt update
sudo apt -y install proton-vpn-gnome-desktop
