#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/docker-validation-resources.sh
source "$repository_root/scripts/lib/docker-validation-resources.sh"

docker run --pull=always --rm \
    "${buildsmith_docker_resource_args[@]}" \
    --mount "type=bind,src=${repository_root},dst=/workspace,readonly" \
    ubuntu:latest bash -eu -c '
        apt-get update >/dev/null
        apt-get install -y --no-install-recommends sudo >/dev/null

        useradd --create-home --shell /bin/bash buildsmith
        printf "%s\n" "buildsmith ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/buildsmith
        chmod 440 /etc/sudoers.d/buildsmith

        touch /tmp/Cursor.AppImage /tmp/cursor-icon.png
        chown buildsmith:buildsmith /tmp/Cursor.AppImage /tmp/cursor-icon.png

        sudo -u buildsmith -H env HOME=/home/buildsmith USER=buildsmith \
            sudo bash /workspace/scripts/create-appimage-desktop.sh \
                /tmp/Cursor.AppImage /tmp/cursor-icon.png

        test "$(stat -c %U:%G /home/buildsmith/.local)" = buildsmith:buildsmith
        test "$(stat -c %U:%G /home/buildsmith/.local/share)" = buildsmith:buildsmith
        test "$(stat -c %U:%G /home/buildsmith/.local/share/applications)" = buildsmith:buildsmith
        test "$(stat -c %U:%G /home/buildsmith/.local/share/applications/Cursor.desktop)" = buildsmith:buildsmith
    '

printf '%s\n' 'AppImage desktop integration preserves user-local ownership.'
