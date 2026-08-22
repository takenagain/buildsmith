#!/bin/sh

set -eu

# Install the current Alpine Python and supported tooling.
sudo apk add --no-cache python3 py3-pip pipx readline-dev
export PATH="$HOME/.local/bin:$PATH"
if ! grep -qx 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi

pipx ensurepath
pipx install poetry

# Install current uv tooling.
curl -LsSf https://astral.sh/uv/install.sh | sh
