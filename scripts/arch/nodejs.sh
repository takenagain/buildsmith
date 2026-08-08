#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm nodejs npm

npm config set prefix "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
if ! grep -Fqx 'PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
    printf '%s\n' 'PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi

npm install --global npm@latest npm-check-updates
