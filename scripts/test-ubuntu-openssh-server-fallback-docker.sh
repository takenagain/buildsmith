#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/docker-validation-resources.sh
source "$repository_root/scripts/lib/docker-validation-resources.sh"
test_public_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuildsmithOpenSshFallbackKey buildsmith@docker'

docker run --pull=always --privileged --rm \
    "${buildsmith_docker_resource_args[@]}" \
    --mount "type=bind,src=${repository_root},dst=/workspace,readonly" \
    --env DEBIAN_FRONTEND=noninteractive \
    --env SSH_PUBLIC_KEY="$test_public_key" \
    --env SSH_PORT=2222 \
    ubuntu:26.04 bash -euo pipefail -c '
        . /etc/os-release
        if [ "$ID" != ubuntu ] || [ "$VERSION_ID" != 26.04 ]; then
            echo "Expected Ubuntu 26.04, found ${PRETTY_NAME:-unknown}." >&2
            exit 1
        fi

        apt-get update
        apt-get install -y --no-install-recommends sudo systemd
        useradd --create-home --shell /bin/bash buildsmith
        printf "buildsmith ALL=(ALL) NOPASSWD: ALL\n" > /etc/sudoers.d/buildsmith
        chmod 440 /etc/sudoers.d/buildsmith

        systemctl_status=0
        systemctl is-system-running >/tmp/systemctl-is-system-running.log 2>&1 || systemctl_status=$?
        if [ "$systemctl_status" -eq 0 ]; then
            echo "Expected systemctl is-system-running to select the direct-daemon fallback." >&2
            exit 1
        fi
        printf "systemctl is-system-running exited %s; exercising the direct-daemon fallback.\n" \
            "$systemctl_status"

        sudo -u buildsmith -H env \
            CI=1 \
            HOME=/home/buildsmith \
            USER=buildsmith \
            SSH_PUBLIC_KEY="$SSH_PUBLIC_KEY" \
            SSH_PORT="$SSH_PORT" \
            PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
            bash /workspace/scripts/debian/openssh-server.sh

        test -s /run/sshd.pid
        kill -0 "$(cat /run/sshd.pid)"
        echo "Ubuntu OpenSSH direct-daemon fallback passed."
    '
