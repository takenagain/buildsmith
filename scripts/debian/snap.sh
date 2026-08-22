#!/usr/bin/env bash

set -euo pipefail

snapd_is_ready() {
    [ -S /run/snapd.socket ] || return 1
    timeout 5 snap changes >/dev/null 2>&1
}

snap_install() {
    sudo env -u DBUS_SESSION_BUS_ADDRESS \
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket \
        snap install "$@"
}

if ! command -v snap >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y snapd squashfs-tools
fi

if ! snapd_is_ready; then
    snapd_binary="$(command -v snapd || printf '%s' /usr/lib/snapd/snapd)"
    if [ "$(ps -p 1 -o comm= 2>/dev/null)" = 'systemd' ] && command -v systemctl >/dev/null 2>&1; then
        sudo systemctl daemon-reload
        sudo systemctl enable --now snapd.socket
    else
        sudo "$snapd_binary" >/tmp/snapd.log 2>&1 &
    fi
    for _ in $(seq 1 30); do
        if snapd_is_ready; then
            break
        fi
        sleep 1
    done
fi

if ! snapd_is_ready; then
    echo "snapd did not become ready" >&2
    exit 1
fi

sudo env -u DBUS_SESSION_BUS_ADDRESS \
    DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket \
    snap wait system seed.loaded

snap_install bitwarden
snap_install obsidian --classic
snap_install vlc
snap_install codium --classic
snap_install go --classic
snap_install remmina
snap_install brave
snap_install telegram-desktop
