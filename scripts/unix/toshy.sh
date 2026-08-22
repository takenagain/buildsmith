#!/usr/bin/env bash

set -euo pipefail

if [ "${CI:-0}" = "1" ] || { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; }; then
    printf '%s\n' 'Skipping Toshy setup: a graphical desktop session is required (headless or CI environment detected).'
    exit 0
fi

if [ ! -d toshy/.git ]; then
    git clone https://github.com/RedBearAK/toshy.git
fi
cd toshy
# `sudo -u` leaves this marker behind after dropping to the runner user, which
# Toshy otherwise mistakes for an elevated installer process.
env -u SUDO_USER ./setup_toshy.py install
