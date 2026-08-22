#!/usr/bin/env bash

set -euo pipefail

sudo apt-get install -y podman

sudo flatpak install -y flathub io.podman_desktop.PodmanDesktop
