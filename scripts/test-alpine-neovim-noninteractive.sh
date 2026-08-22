#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"

trap 'rm -rf -- "$test_root"' EXIT

fail() {
    printf 'Alpine Neovim non-interactive test failure: %s\n' "$1" >&2
    exit 1
}

mkdir -p "$test_root/bin" "$test_root/home"

cat > "$test_root/bin/apk" <<'FAKE_APK'
#!/bin/sh

if [ "${BUILD_SMITH_SUDO:-0}" != '1' ]; then
    printf '%s\n' 'apk must be invoked through sudo' > "${UNPRIVILEGED_APK_CALL:?}"
    exit 99
fi

printf 'apk %s\n' "$*" >> "${INSTALL_CALLS:?}"
FAKE_APK

cat > "$test_root/bin/sudo" <<'FAKE_SUDO'
#!/bin/sh

printf 'sudo %s\n' "$*" >> "${SUDO_CALLS:?}"
BUILD_SMITH_SUDO=1 exec "$@"
FAKE_SUDO

cat > "$test_root/bin/git" <<'FAKE_GIT'
#!/bin/sh

if [ ! -d "$HOME/.config" ]; then
    printf '%s\n' 'NvChad parent configuration directory is missing' >&2
    exit 98
fi

printf 'git %s\n' "$*" >> "${INSTALL_CALLS:?}"
FAKE_GIT

for command in brew curl; do
    cat > "$test_root/bin/$command" <<'POISON_HOMEBREW_COMMAND'
#!/bin/sh

printf '%s\n' "$(basename "$0")" >> "${HOMEBREW_CALLS:?}"
printf 'Homebrew command must not run during non-interactive Alpine setup: %s\n' "$(basename "$0")" >&2
exit 97
POISON_HOMEBREW_COMMAND
done

chmod +x "$test_root/bin/"*

output=''
if ! output="$(
    printf 'y\n' | env \
        CI=0 \
        HOME="$test_root/home" \
        HOMEBREW_CALLS="$test_root/homebrew-calls" \
        INSTALL_CALLS="$test_root/install-calls" \
        SUDO_CALLS="$test_root/sudo-calls" \
        UNPRIVILEGED_APK_CALL="$test_root/unprivileged-apk-call" \
        PATH="$test_root/bin:/usr/bin:/bin" \
        bash "$repository_root/scripts/alpine/neovim.sh" 2>&1
)"; then
    fail "script did not complete successfully: $output"
fi

if printf '%s\n' "$output" | grep -F 'Do you want to install Homebrew' >/dev/null; then
    fail 'script prompted for Homebrew without a TTY'
fi

if [ -e "$test_root/homebrew-calls" ]; then
    fail "script invoked Homebrew tooling without a TTY: $(tr '\n' ' ' < "$test_root/homebrew-calls")"
fi

if [ -e "$test_root/unprivileged-apk-call" ]; then
    fail "script invoked apk without sudo: $(cat "$test_root/unprivileged-apk-call")"
fi

if [ "$(wc -l < "$test_root/install-calls" | tr -d '[:space:]')" != '3' ]; then
    fail 'script did not complete its Alpine package and NvChad setup steps'
fi

if [ "$(wc -l < "$test_root/sudo-calls" | tr -d '[:space:]')" != '2' ]; then
    fail 'script did not use sudo for both Alpine package operations'
fi

script_command="$(command -v script)" || fail 'util-linux script command is required for the CI TTY contract'
tty_output=''
if ! tty_output="$(
    env \
        CI=1 \
        HOME="$test_root/tty-home" \
        HOMEBREW_CALLS="$test_root/tty-homebrew-calls" \
        INSTALL_CALLS="$test_root/tty-install-calls" \
        SUDO_CALLS="$test_root/tty-sudo-calls" \
        UNPRIVILEGED_APK_CALL="$test_root/tty-unprivileged-apk-call" \
        PATH="$test_root/bin:/usr/bin:/bin" \
        "$script_command" -qec "bash '$repository_root/scripts/alpine/neovim.sh'" /dev/null < /dev/null 2>&1
)"; then
    fail "script did not complete successfully in a CI TTY: $tty_output"
fi

if printf '%s\n' "$tty_output" | grep -F 'Do you want to install Homebrew' >/dev/null; then
    fail 'script prompted for Homebrew under CI=1 with a TTY'
fi

if [ -e "$test_root/tty-homebrew-calls" ]; then
    fail "script invoked Homebrew tooling under CI=1 with a TTY: $(tr '\n' ' ' < "$test_root/tty-homebrew-calls")"
fi

if [ "$(wc -l < "$test_root/tty-install-calls" | tr -d '[:space:]')" != '3' ] || \
    [ "$(wc -l < "$test_root/tty-sudo-calls" | tr -d '[:space:]')" != '2' ]; then
    fail 'script did not complete package and NvChad setup under CI=1 with a TTY'
fi

printf '%s\n' 'Alpine Neovim non-interactive behavior passed.'
