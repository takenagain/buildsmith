#!/usr/bin/env bash

set -euo pipefail

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo apt-get install -y flatpak

sudo apt-get install -y gnome-software-plugin-flatpak

flathub_repo="$(mktemp /tmp/flathub.XXXXXX.flatpakrepo)"
trap 'rm -f "$flathub_repo"' EXIT
curl -fsSL --retry 5 --retry-all-errors \
    https://dl.flathub.org/repo/flathub.flatpakrepo \
    -o "$flathub_repo"
sudo flatpak remote-add --if-not-exists flathub "$flathub_repo"
