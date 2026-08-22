#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/docker-validation-resources.sh
source "$repository_root/scripts/lib/docker-validation-resources.sh"

docker run --pull=always --rm \
    "${buildsmith_docker_resource_args[@]}" \
    --mount "type=bind,src=${repository_root},dst=/workspace,readonly" \
    --workdir /workspace \
    archlinux:base bash -euo pipefail -c '
        pacman-key --init
        pacman -Syu --needed --noconfirm sudo ca-certificates

        useradd --create-home --shell /bin/bash buildsmith
        printf "%s\n" "buildsmith ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/buildsmith
        chmod 440 /etc/sudoers.d/buildsmith

        install -d -m 755 /home/buildsmith/.local/share/applications
        test "$(stat -c %U:%G /home/buildsmith/.local)" = root:root

        sudo -u buildsmith -H env \
            HOME=/home/buildsmith \
            USER=buildsmith \
            PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
            bash /workspace/scripts/arch/nodejs.sh

        test "$(sudo -u buildsmith -H env HOME=/home/buildsmith npm config get prefix)" = /home/buildsmith/.local
        test "$(sudo -u buildsmith -H env HOME=/home/buildsmith npm root --global)" = /home/buildsmith/.local/lib/node_modules
        test "$(stat -c %U:%G /home/buildsmith/.local/bin)" = buildsmith:buildsmith
        test "$(stat -c %U:%G /home/buildsmith/.local/lib)" = buildsmith:buildsmith
        test -x /home/buildsmith/.local/bin/npm
        test -x /home/buildsmith/.local/bin/ncu
    '

printf '%s\n' 'Arch Node.js non-root prefix validation passed.'
