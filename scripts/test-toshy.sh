#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
toshy_script="$repository_root/scripts/unix/toshy.sh"
test_root="$(mktemp -d)"
git_called_marker="$test_root/git-called"

trap 'rm -rf "$test_root"' EXIT

fail() {
    printf 'Toshy test failure: %s\n' "$1" >&2
    exit 1
}

mkdir -p "$test_root/bin"
cat > "$test_root/bin/git" <<'EOF'
#!/usr/bin/env bash

: > "${GIT_CALLED_MARKER:?}"
exit 97
EOF
chmod +x "$test_root/bin/git"

run_headless_test() {
    local case_name="$1"
    shift
    local working_directory="$test_root/$case_name"
    local output=''

    mkdir -p "$working_directory"
    rm -f "$git_called_marker"

    if ! output="$(
        cd "$working_directory"
        env \
            -u DISPLAY \
            -u WAYLAND_DISPLAY \
            GIT_CALLED_MARKER="$git_called_marker" \
            PATH="$test_root/bin:$PATH" \
            "$@" bash "$toshy_script"
    )"; then
        fail "$case_name invocation did not exit successfully"
    fi

    case "$output" in
        *'Skipping Toshy setup:'*) ;;
        *) fail "$case_name invocation did not explain why setup was skipped" ;;
    esac
    [ ! -e "$git_called_marker" ] || fail "$case_name invocation attempted a network clone"
}

run_headless_test headless env -u CI
run_headless_test ci env CI=1 DISPLAY=:99

desktop_directory="$test_root/desktop"
setup_log="$test_root/setup.log"
mkdir -p "$desktop_directory/toshy/.git"
cat > "$desktop_directory/toshy/setup_toshy.py" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

printf 'arguments=%s\n' "$*" > "${TOSHY_TEST_LOG:?}"
if [ -n "${SUDO_USER+x}" ]; then
    printf 'sudo-user=%s\n' "$SUDO_USER" >> "$TOSHY_TEST_LOG"
else
    printf 'sudo-user=unset\n' >> "$TOSHY_TEST_LOG"
fi
EOF
chmod +x "$desktop_directory/toshy/setup_toshy.py"

(
    cd "$desktop_directory"
    env \
        -u CI \
        -u WAYLAND_DISPLAY \
        DISPLAY=:99 \
        SUDO_USER=stale-runner-user \
        TOSHY_TEST_LOG="$setup_log" \
        PATH="$test_root/bin:$PATH" \
        bash "$toshy_script"
)

grep -qx 'arguments=install' "$setup_log" || fail 'desktop invocation did not reach the Toshy installer'
grep -qx 'sudo-user=unset' "$setup_log" || fail 'desktop invocation leaked the stale SUDO_USER value'

printf 'Toshy headless and desktop invocation tests passed.\n'
