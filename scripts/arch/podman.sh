#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm podman podman-compose buildah skopeo

current_user="$(id -un)"
if ! grep -q "^${current_user}:" /etc/subuid; then
    echo "${current_user}:100000:65536" | sudo tee -a /etc/subuid >/dev/null
fi
if ! grep -q "^${current_user}:" /etc/subgid; then
    echo "${current_user}:100000:65536" | sudo tee -a /etc/subgid >/dev/null
fi
