#!/usr/bin/env bash

set -euo pipefail

font_name='JetBrainsMono'
font_directory="$HOME/.local/share/fonts/$font_name"
archive_directory="$(mktemp -d)"
archive_path="$archive_directory/$font_name.tar.xz"
trap 'rm -rf "$archive_directory"' EXIT

mkdir -p "$font_directory"
curl -fsSL --retry 3 --retry-all-errors \
    -o "$archive_path" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.tar.xz"
tar -xJf "$archive_path" -C "$font_directory"
fc-cache -f "$font_directory"
