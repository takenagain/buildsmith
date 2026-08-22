#!/usr/bin/env bash

set -euo pipefail

run_container() {
    local image="$1"
    local prerequisites="$2"
    local shell="$3"

    printf 'Validating installer in %s\n' "$image"
    docker run --pull=always --rm \
        "${buildsmith_docker_resource_args[@]}" \
        --mount "type=bind,src=${repository_root},dst=/workspace,readonly" \
        --workdir /workspace \
        --env CI=1 \
        --env DEBIAN_FRONTEND=noninteractive \
        --env CARGO_HOME=/tmp/cargo \
        --env RUSTUP_HOME=/tmp/rustup \
        --env CARGO_TARGET_DIR=/tmp/target \
        "$image" \
        "$shell" -eu -c "${prerequisites} && bash ./install.sh && test -x /tmp/target/release/runner && printf 'Built release runner in %s\\n' '${image}'"
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/docker-validation-resources.sh
source "$repository_root/scripts/lib/docker-validation-resources.sh"

run_container "ubuntu:latest" "apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl" bash
run_container "debian:latest" "apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl" bash
run_container "alpine:latest" "apk add --no-cache bash ca-certificates curl" sh
run_container "archlinux:base" "pacman-key --init && pacman -Syu --needed --noconfirm bash ca-certificates curl" bash
