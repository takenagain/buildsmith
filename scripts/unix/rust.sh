#!/usr/bin/env bash

set -euo pipefail

cargo_home="${CARGO_HOME:-$HOME/.cargo}"
CARGO_BIN_DIR="$cargo_home/bin"
export PATH="$CARGO_BIN_DIR:$PATH"

if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

if [ -f "$cargo_home/env" ]; then
    # shellcheck disable=SC1090
    source "$cargo_home/env"
fi

rustup toolchain install stable
rustup default stable
