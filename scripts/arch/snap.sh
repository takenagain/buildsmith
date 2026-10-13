#!/usr/bin/env bash

set -euo pipefail

if ! command -v yay >/dev/null 2>&1; then
    echo "Snap setup requires yay; run the Arch yay action first." >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "Snap setup must run as a non-root user so yay can build snapd." >&2
    exit 1
fi

yay -S --needed --noconfirm snapd

if [ -L /snap ]; then
    if [ "$(readlink /snap)" != '/var/lib/snapd/snap' ]; then
        echo "/snap points somewhere other than /var/lib/snapd/snap; refusing to replace it." >&2
        exit 1
    fi
elif [ ! -e /snap ]; then
    sudo ln -s /var/lib/snapd/snap /snap
else
    echo "/snap already exists and is not a symlink; refusing to replace it." >&2
    exit 1
fi

sudo systemctl enable --now snapd.socket

echo "Snap is ready. Full Snap confinement also requires AppArmor to be enabled in the kernel and system services."
