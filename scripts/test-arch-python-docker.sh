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

        # The earlier privileged desktop integration creates these user-local
        # paths as root. Python setup must still initialize per-user pipx.
        install -d -m 755 /home/buildsmith/.local/share/applications
        test "$(stat -c %U:%G /home/buildsmith/.local)" = root:root
        test "$(stat -c %U:%G /home/buildsmith/.local/share)" = root:root

        sudo -u buildsmith -H env \
            HOME=/home/buildsmith \
            USER=buildsmith \
            LOGNAME=buildsmith \
            PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
            bash /workspace/scripts/arch/python.sh

        for directory in \
            /home/buildsmith/.local \
            /home/buildsmith/.local/bin \
            /home/buildsmith/.local/share \
            /home/buildsmith/.local/state; do
            test "$(stat -c %U:%G "$directory")" = buildsmith:buildsmith
        done

        # The repair is deliberately non-recursive: unrelated files installed
        # by the privileged desktop helper retain their existing ownership.
        test "$(stat -c %U:%G /home/buildsmith/.local/share/applications)" = root:root

        pipx_home="$(sudo -u buildsmith -H env HOME=/home/buildsmith pipx environment --value PIPX_HOME)"
        pipx_log_dir="$(sudo -u buildsmith -H env HOME=/home/buildsmith pipx environment --value PIPX_LOG_DIR)"
        test "$pipx_home" = /home/buildsmith/.local/share/pipx
        test "$pipx_log_dir" = /home/buildsmith/.local/state/pipx/log
        test -d "$pipx_log_dir"
    '

printf '%s\n' 'Arch Python pipx user-directory validation passed.'
