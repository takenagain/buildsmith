#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm gnome-shell extension-manager

echo "Extension Manager is installed. Open it from the GNOME applications menu to browse, install, update, and remove extensions."
