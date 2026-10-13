#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/docker-validation-resources.sh
source "$repository_root/scripts/lib/docker-validation-resources.sh"
host_kernel_modules_dir="/lib/modules/$(uname -r)"
test_public_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuildsmithDockerValidationKey buildsmith@docker'

run_container() {
    local image="$1"
    local shell="$2"
    local prerequisites="$3"
    local container_id=''
    local container_status=''
    local container_ready=0
    local apparmor_namespace=''
    local -a docker_run_args docker_command

    printf '\n=== Validating selected scripts in %s ===\n' "$image"
    docker_run_args=(
        docker run --pull=always --privileged
        "${buildsmith_docker_resource_args[@]}"
        # Toshy needs the host kernel's uinput interface. The module metadata
        # lets modprobe recognize kernels that build uinput into the kernel.
        --device /dev/uinput:/dev/uinput
        --mount "type=bind,src=${repository_root},dst=/workspace,readonly"
        --mount "type=bind,src=${host_kernel_modules_dir},dst=${host_kernel_modules_dir},readonly"
        --workdir /workspace
        --env CI=1
        --env DEBIAN_FRONTEND=noninteractive
        --env SSH_PUBLIC_KEY="$test_public_key"
        --env SSH_PORT=2222
        --env CARGO_HOME=/tmp/cargo
        --env RUSTUP_HOME=/tmp/rustup
        --env CARGO_TARGET_DIR=/tmp/target
    )
    if [ "$image" = 'ubuntu:latest' ]; then
        if [ ! -d /sys/kernel/security/apparmor/policy/namespaces ]; then
            echo "Ubuntu snap validation requires an AppArmor policy namespace-capable host kernel." >&2
            exit 1
        fi
        apparmor_namespace="buildsmith-validation-$$"
        docker run --pull=always --privileged --rm \
            --mount type=bind,src=/sys/kernel/security,dst=/sys/kernel/security \
            ubuntu:latest bash -eu -c \
            "mkdir /sys/kernel/security/apparmor/policy/namespaces/$apparmor_namespace"
        trap "docker run --pull=never --privileged --rm --mount type=bind,src=/sys/kernel/security,dst=/sys/kernel/security ubuntu:latest bash -eu -c 'rmdir /sys/kernel/security/apparmor/policy/namespaces/$apparmor_namespace' >/dev/null 2>&1 || true" EXIT
        container_id="$(
            "${docker_run_args[@]}" --detach \
                --cgroupns=private \
                --tmpfs /run \
                --tmpfs /run/lock \
                --mount type=bind,src=/sys/kernel/security,dst=/sys/kernel/security \
                --security-opt "apparmor=:$apparmor_namespace:unconfined" \
                "$image" bash -c \
                'apt-get update && apt-get install -y --no-install-recommends systemd dbus dbus-user-session && touch /var/lib/buildsmith-systemd-bootstrap-ready && exec /lib/systemd/systemd'
        )"
        trap "docker rm --force '$container_id' >/dev/null 2>&1 || true; docker run --pull=never --privileged --rm --mount type=bind,src=/sys/kernel/security,dst=/sys/kernel/security ubuntu:latest bash -eu -c 'rmdir /sys/kernel/security/apparmor/policy/namespaces/$apparmor_namespace' >/dev/null 2>&1 || true" EXIT
        for _ in $(seq 1 180); do
            container_status="$(docker inspect --format '{{.State.Status}}' "$container_id")"
            if [ "$container_status" = 'running' ] && \
                docker exec "$container_id" test -e /var/lib/buildsmith-systemd-bootstrap-ready >/dev/null 2>&1; then
                container_ready=1
                break
            fi
            sleep 1
        done
        if [ "$container_status" != 'running' ] || [ "$container_ready" -ne 1 ]; then
            docker logs "$container_id"
            exit 1
        fi
        if docker exec "$container_id" grep -Eq '/docker-[[:xdigit:]]+\.scope(/|$)' /proc/1/cgroup; then
            echo "Ubuntu snap validation requires a private cgroup namespace so systemd does not inherit Docker's cgroup path." >&2
            exit 1
        fi
        docker_command=(docker exec "$container_id")
    else
        docker_command=(
            "${docker_run_args[@]}" --rm
                "$image"
        )
    fi

    "${docker_command[@]}" "$shell" -eu -c "
            ${prerequisites}
            if command -v apt-get >/dev/null 2>&1; then
                apt-get install -y --no-install-recommends sudo ca-certificates curl git openssh-client
                useradd --create-home --shell /bin/bash buildsmith
            elif command -v apk >/dev/null 2>&1; then
                apk add --no-cache sudo ca-certificates curl git openssh-client bash shadow
                adduser -D -s /bin/bash buildsmith
            else
                pacman -Syu --needed --noconfirm sudo ca-certificates curl git openssh
                useradd --create-home --shell /bin/bash buildsmith
            fi
            printf 'buildsmith ALL=(ALL) NOPASSWD: ALL\\n' > /etc/sudoers.d/buildsmith
            chmod 440 /etc/sudoers.d/buildsmith
            # These privileged containers have a private /dev tmpfs, so grant
            # only the non-root installer user access to its copied node.
            chown buildsmith:buildsmith /dev/uinput
            if command -v dbus-daemon >/dev/null 2>&1 && \
                [ \"\$(ps -p 1 -o comm= 2>/dev/null)\" != systemd ]; then
                install -d -m 755 /run/dbus
                dbus-daemon --system --fork
            fi
            if [ \"\$(ps -p 1 -o comm= 2>/dev/null)\" = systemd ] && \\
                ! busctl --system status org.freedesktop.systemd1 >/dev/null 2>&1; then
                echo 'The system D-Bus is not connected to systemd PID 1.' >&2
                exit 1
            fi
            buildsmith_uid=\$(id -u buildsmith)
            install -d -m 700 -o buildsmith -g buildsmith \"/run/user/\$buildsmith_uid\"
            CI=1 bash ./install.sh
            log_file=/tmp/buildsmith-script-run.log
            collected_scripts_file=/tmp/buildsmith-collected-scripts.csv
            if command -v dbus-run-session >/dev/null 2>&1; then
                runner_prefix='dbus-run-session --'
            else
                runner_prefix=''
            fi
            sudo -u buildsmith -H env \\
                HOME=/home/buildsmith \\
                USER=buildsmith \\
                PATH=/tmp/target/release:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
                /tmp/target/release/runner -s /workspace/scripts list --format csv \\
                > \"\$collected_scripts_file\"
            if ! sudo -u buildsmith -H env \\
                CI=1 \\
                HOME=/home/buildsmith \\
                USER=buildsmith \\
                XDG_RUNTIME_DIR="/run/user/\$buildsmith_uid" \\
                SSH_PUBLIC_KEY=\"${test_public_key}\" \\
                SSH_PORT=2222 \\
                NVM_MAKE_JOBS="$buildsmith_build_jobs" \\
                PATH=/tmp/target/release:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
                sh -c \"\$runner_prefix /tmp/target/release/runner -s /workspace/scripts run-all --exclude docker --exclude yubikey --exclude gnome-extensions --exclude protonvpn --exclude rocm --exclude snap\" 2>&1 | tee \"\$log_file\"; then
                exit 1
            fi
            grep -F 'All selected scripts completed successfully' \"\$log_file\"
            if grep -F 'No scripts remain after applying exclusions' \"\$log_file\"; then
                exit 1
            fi
            bash /workspace/scripts/verify-script-run-log.sh \\
                /workspace/scripts \\
                \"\$collected_scripts_file\" \\
                \"\$log_file\" \\
                docker yubikey gnome-extensions protonvpn rocm snap
        "
}

run_container "ubuntu:latest" bash "apt-get update && apt-get install -y --no-install-recommends bash build-essential ca-certificates curl dbus dbus-user-session"
run_container "alpine:latest" sh "apk add --no-cache bash build-base ca-certificates curl dbus"
run_container "archlinux:base" bash "pacman-key --init && pacman -Syu --needed --noconfirm bash base-devel ca-certificates curl dbus"

printf '\nAll selected Linux script validations passed.\n'
