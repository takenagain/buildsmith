#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm docker docker-compose

if ! getent group docker >/dev/null; then
    sudo groupadd docker
fi

sudo systemctl enable --now docker.service
sudo usermod -aG docker "$(id -un)"

echo "Docker Engine is enabled. The docker group grants root-equivalent access; sign out and back in to use it without sudo."
