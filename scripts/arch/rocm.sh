#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm rocm-hip-sdk
sudo usermod -aG render,video "$(id -un)"

echo "ROCm is installed. Log out and back in for render/video group access; GPU support depends on the installed AMD hardware."
