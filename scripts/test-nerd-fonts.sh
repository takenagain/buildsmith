#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/fake-bin"
test_home="$test_root/home"
font_source="$test_root/font-source"
archive="$test_root/JetBrainsMono.tar.xz"
font_cache_log="$test_root/font-cache.log"
mkdir -p "$fake_bin" "$test_home" "$font_source"

printf '%s\n' 'test font data' > "$font_source/JetBrainsMonoNerdFont-Regular.ttf"
tar -cJf "$archive" -C "$font_source" JetBrainsMonoNerdFont-Regular.ttf

printf '%s\n' \
    '#!/bin/sh' \
    'destination=' \
    'while [ "$#" -gt 0 ]; do' \
    '    case "$1" in' \
    '        -o)' \
    '            shift' \
    '            destination="$1"' \
    '            ;;' \
    '    esac' \
    '    shift' \
    'done' \
    'test -n "$destination"' \
    'cp "$NERD_FONT_TEST_ARCHIVE" "$destination"' \
    > "$fake_bin/curl"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$fake_bin/git"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$*" > "$NERD_FONT_TEST_CACHE_LOG"' \
    > "$fake_bin/fc-cache"
chmod +x "$fake_bin/curl" "$fake_bin/git" "$fake_bin/fc-cache"

(
    cd "$test_root"
    HOME="$test_home" \
        NERD_FONT_TEST_ARCHIVE="$archive" \
        NERD_FONT_TEST_CACHE_LOG="$font_cache_log" \
        PATH="$fake_bin:$PATH" \
        bash "$repository_root/scripts/unix/nerd-fonts.sh"
)

font_directory="$test_home/.local/share/fonts/JetBrainsMono"
test -f "$font_directory/JetBrainsMonoNerdFont-Regular.ttf"
test "$(cat "$font_cache_log")" = "-f $font_directory"

printf '%s\n' 'Nerd Fonts release-archive installation passed.'
