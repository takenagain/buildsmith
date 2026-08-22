#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    printf 'contract failure: %s\n' "$1" >&2
    exit 1
}

assert_file() {
    [ -f "$1" ] || fail "missing file: $1"
}

assert_contains() {
    local pattern="$1"
    local file="$2"
    rg -q --fixed-strings -- "$pattern" "$file" || fail "missing '$pattern' in $file"
}

assert_not_contains() {
    local pattern="$1"
    local file="$2"
    if rg -q --fixed-strings -- "$pattern" "$file"; then
        fail "unexpected '$pattern' in $file"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    [ "$actual" = "$expected" ] || fail "$message: expected '$expected', got '$actual'"
}

directory_mode() {
    local directory="$1"

    if stat -c '%a' "$directory" 2>/dev/null; then
        return
    fi

    stat -f '%Lp' "$directory"
}

resident_key_fixture_root=""

cleanup_resident_key_fixture() {
    if [ -n "$resident_key_fixture_root" ]; then
        rm -rf -- "$resident_key_fixture_root"
    fi
}

test_resident_keys_are_downloaded_in_user_ssh_directory() {
    local fake_bin
    local platform
    local script
    local home_dir
    local invocation_dir
    local runtime_dir
    local cwd_log
    local expected_cwd
    local actual_cwd
    local ssh_dir_mode
    local caller_cwd

    resident_key_fixture_root="$(mktemp -d)"
    trap cleanup_resident_key_fixture EXIT
    fake_bin="$resident_key_fixture_root/bin"
    mkdir -p "$fake_bin"

    cat > "$fake_bin/id" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "-u" ]; then
    printf '1000\n'
    exit 0
fi

exit 1
EOF

    cat > "$fake_bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--prefix" ]; then
    printf '%s\n' "$FAKE_BREW_PREFIX"
fi
EOF

    cat > "$fake_bin/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ "$1" != "-K" ]; then
    printf 'unexpected ssh-keygen arguments: %s\n' "$*" >&2
    exit 1
fi

pwd -P > "$SSH_KEYGEN_CWD_LOG"
EOF

    cat > "$fake_bin/noop" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    chmod +x "$fake_bin/id" "$fake_bin/brew" "$fake_bin/ssh-keygen" "$fake_bin/noop"
    for platform in sudo systemctl yay yubikey-agent launchctl; do
        ln -s "$fake_bin/noop" "$fake_bin/$platform"
    done

    caller_cwd="$(pwd -P)"
    for platform in debian arch darwin; do
        script="$repository_root/scripts/$platform/yubikey.sh"
        home_dir="$resident_key_fixture_root/home/$platform"
        invocation_dir="$resident_key_fixture_root/invocation/$platform"
        runtime_dir="$resident_key_fixture_root/runtime/$platform"
        cwd_log="$resident_key_fixture_root/$platform-ssh-keygen-cwd"
        mkdir -p "$home_dir" "$invocation_dir" "$runtime_dir"

        (
            cd "$invocation_dir"
            umask 022
            CI=0 \
                FAKE_BREW_PREFIX="$fake_bin" \
                HOME="$home_dir" \
                PATH="$fake_bin:/usr/bin:/bin" \
                SSH_KEYGEN_CWD_LOG="$cwd_log" \
                XDG_RUNTIME_DIR="$runtime_dir" \
                bash "$script" >/dev/null
        )

        expected_cwd="$(cd "$home_dir/.ssh" && pwd -P)"
        actual_cwd="$(<"$cwd_log")"
        assert_equals "$expected_cwd" "$actual_cwd" \
            "$platform ssh-keygen -K working directory"

        ssh_dir_mode="$(directory_mode "$home_dir/.ssh")"
        assert_equals "700" "$ssh_dir_mode" "$platform HOME/.ssh mode"
    done

    assert_equals "$caller_cwd" "$(pwd -P)" "caller working directory after YubiKey scripts"
    cleanup_resident_key_fixture
    resident_key_fixture_root=""
    trap - EXIT

    printf 'YubiKey resident-key working-directory contract passed.\n'
}

if [ "${1:-}" = "resident-key-cwd" ]; then
    test_resident_keys_are_downloaded_in_user_ssh_directory
    exit 0
fi

[ "$#" -eq 0 ] || fail "usage: $0 [resident-key-cwd]"

for file in \
    "$repository_root/scripts/debian/yubikey.sh" \
    "$repository_root/scripts/arch/yubikey.sh" \
    "$repository_root/scripts/alpine/yubikey.sh" \
    "$repository_root/scripts/darwin/yubikey.sh" \
    "$repository_root/scripts/windows/yubikey.ps1"; do
    assert_file "$file"
done

assert_contains 'flatpak --user install' "$repository_root/scripts/debian/apt.sh"
assert_not_contains 'libpam-u2f' "$repository_root/scripts/debian/apt.sh"
assert_not_contains 'yubikey-agent' "$repository_root/scripts/debian/apt.sh"
assert_not_contains 'pam-u2f' "$repository_root/scripts/alpine/apk.sh"
assert_contains 'pam-u2f' "$repository_root/scripts/arch/yubikey.sh"
assert_not_contains 'libpam-u2f' "$repository_root/scripts/arch/yubikey.sh"
assert_contains 'yay -S --needed --noconfirm yubikey-agent' "$repository_root/scripts/arch/yubikey.sh"
arch_pacman_line="$(rg -m 1 '^sudo pacman ' "$repository_root/scripts/arch/yubikey.sh")"
if [[ "$arch_pacman_line" == *yubikey-agent* ]]; then
    fail 'Arch pacman package list must not include the AUR-only yubikey-agent'
fi
assert_contains '/usr/lib/snapd/snapd' "$repository_root/scripts/debian/flutter.sh"
assert_contains '/usr/lib/snapd/snapd' "$repository_root/scripts/debian/snap.sh"
assert_contains 'sudo flatpak remote-add' "$repository_root/scripts/debian/flatpak.sh"
assert_contains 'curl -fsSL --retry' "$repository_root/scripts/debian/flatpak.sh"
assert_not_contains '${TMPDIR:-/tmp}' "$repository_root/scripts/debian/flatpak.sh"
assert_contains 'sudo flatpak install' "$repository_root/scripts/debian/podman.sh"

for file in \
    "$repository_root/scripts/debian/git.sh" \
    "$repository_root/scripts/arch/git.sh" \
    "$repository_root/scripts/alpine/git.sh" \
    "$repository_root/scripts/darwin/git.sh" \
    "$repository_root/scripts/windows/git.ps1"; do
    assert_not_contains "yubikey-agent" "$file"
    assert_not_contains "yubikey-manager" "$file"
    assert_not_contains "ssh-keygen -K" "$file"
done

for file in \
    "$repository_root/scripts/debian/yubikey.sh" \
    "$repository_root/scripts/arch/yubikey.sh"; do
    assert_contains "systemctl --user daemon-reload" "$file"
    assert_contains "systemctl --user enable --now yubikey-agent.service" "$file"
    assert_contains "RuntimeDirectory=yubikey-agent" "$file"
    assert_contains '%t/yubikey-agent/yubikey-agent.sock' "$file"
    assert_contains 'systemctl --user import-environment' "$file"
done

assert_contains 'sudo apk add --no-cache' "$repository_root/scripts/alpine/yubikey.sh"
assert_contains 'gnupg-scdaemon' "$repository_root/scripts/alpine/yubikey.sh"
assert_contains 'gpgconf --launch gpg-agent' "$repository_root/scripts/alpine/yubikey.sh"
assert_contains 'RunAll' "$repository_root/runner/src/cli/mod.rs"
assert_contains 'long = "exclude"' "$repository_root/runner/src/cli/mod.rs"
assert_contains 'run_all_scripts' "$repository_root/runner/src/cli/commands.rs"

test_resident_keys_are_downloaded_in_user_ssh_directory

printf 'YubiKey separation and run-all contracts passed.\n'
