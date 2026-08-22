#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/docker-validation-resources.sh
source "$repository_root/scripts/lib/docker-validation-resources.sh"
test_public_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuildsmithAlpineOpenSshKey buildsmith@docker'

docker run --pull=always --privileged --rm \
    "${buildsmith_docker_resource_args[@]}" \
    --mount "type=bind,src=${repository_root},dst=/workspace,readonly" \
    --env SSH_PUBLIC_KEY="$test_public_key" \
    --env SSH_PORT=2222 \
    alpine:latest sh -eu -c '
        apk add --no-cache bash build-base ca-certificates cargo sudo >/dev/null
        CARGO_HOME=/tmp/cargo CARGO_TARGET_DIR=/tmp/target \
            cargo build --release --manifest-path /workspace/runner/Cargo.toml
        adduser -D -s /bin/bash buildsmith
        printf "buildsmith ALL=(ALL) NOPASSWD: ALL\n" > /etc/sudoers.d/buildsmith
        chmod 440 /etc/sudoers.d/buildsmith

        sudo -u buildsmith -H env \
            CI=1 \
            HOME=/home/buildsmith \
            USER=buildsmith \
            SSH_PUBLIC_KEY="$SSH_PUBLIC_KEY" \
            SSH_PORT="$SSH_PORT" \
            PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
            sh -c "/tmp/target/release/runner -s /workspace/scripts run \"openssh-server.sh [alpine]\""

        test -s /run/sshd.pid
        kill -0 "$(cat /run/sshd.pid)"
        grep -Fqx "Port 2222" /etc/ssh/sshd_config
        grep -Fqx "PasswordAuthentication no" /etc/ssh/sshd_config
        grep -Fqx "$SSH_PUBLIC_KEY" /home/buildsmith/.ssh/authorized_keys
        test "$(stat -c %U:%G /home/buildsmith/.ssh/authorized_keys)" = buildsmith:buildsmith
        grep -F -- "--dport 2222" /etc/iptables/rules.v4 >/dev/null
    '

printf '%s\n' 'Alpine OpenSSH non-root runner validation passed.'
