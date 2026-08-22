#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/fake-bin"
test_home="$test_root/home"
package_log="$test_root/apk.log"
tee_log="$test_root/tee.log"
mkdir -p "$fake_bin" "$test_home"

printf '%s\n' \
    '#!/bin/sh' \
    'if [ "${FAKE_SUDO:-}" != 1 ]; then' \
    '    echo "apk must be invoked through sudo" >&2' \
    '    exit 1' \
    'fi' \
    'printf "%s\n" "$*" >> "$FAKE_APK_LOG"' \
    > "$fake_bin/apk"
printf '%s\n' \
    '#!/bin/sh' \
    'FAKE_SUDO=1' \
    'export FAKE_SUDO' \
    'exec "$@"' \
    > "$fake_bin/sudo"
printf '%s\n' \
    '#!/bin/sh' \
    'if [ "${FAKE_SUDO:-}" != 1 ]; then' \
    '    echo "tee must be invoked through sudo" >&2' \
    '    exit 1' \
    'fi' \
    'cat >> "$FAKE_TEE_LOG"' \
    > "$fake_bin/tee"
printf '%s\n' \
    '#!/bin/sh' \
    'exit 0' \
    > "$fake_bin/pipx"
chmod +x "$fake_bin/apk" "$fake_bin/sudo" "$fake_bin/tee" "$fake_bin/pipx"

HOME="$test_home" \
    USER=buildsmith \
    FAKE_APK_LOG="$package_log" \
    FAKE_TEE_LOG="$tee_log" \
    PATH="$fake_bin:$PATH" \
    /bin/sh "$repository_root/scripts/alpine/podman.sh"
HOME="$test_home" \
    USER=buildsmith \
    FAKE_APK_LOG="$package_log" \
    FAKE_TEE_LOG="$tee_log" \
    PATH="$fake_bin:$PATH" \
    /bin/sh "$repository_root/scripts/alpine/python.sh"

grep -Fx 'add --no-cache podman skopeo buildah' "$package_log"
grep -Fx 'add --no-cache python3 py3-pip pipx readline-dev' "$package_log"
test "$(cat "$tee_log")" = $'buildsmith:100000:65536\nbuildsmith:100000:65536'

printf '%s\n' 'Alpine package-install privilege contract passed.'
