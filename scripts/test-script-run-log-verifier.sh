#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
verifier="$repository_root/scripts/verify-script-run-log.sh"
test_root="$(mktemp -d)"
collected_scripts="$test_root/collected.csv"
runner_log="$test_root/runner.log"
failure_log="$test_root/failure.log"

trap 'rm -rf -- "$test_root"' EXIT

fail() {
    printf 'script-run verifier test failure: %s\n' "$1" >&2
    exit 1
}

[ -f "$verifier" ] || fail "missing verifier: $verifier"
rg -q --fixed-strings 'verify-script-run-log.sh' \
    "$repository_root/scripts/test-scripts-docker.sh" || \
    fail 'Docker harness does not invoke the per-script completion verifier'

cat > "$collected_scripts" <<'EOF'
Script Name,OS Type,Path
act.sh,unix,/workspace/docker-parent/scripts/unix/act.sh
docker-engine.sh,alpine,/workspace/docker-parent/scripts/alpine/docker-engine.sh
git.sh,alpine,/workspace/docker-parent/scripts/alpine/git.sh
yubikey.sh,alpine,/workspace/docker-parent/scripts/alpine/yubikey.sh
EOF

cat > "$runner_log" <<'EOF'
[INFO runner] Script completed successfully: /workspace/docker-parent/scripts/unix/act.sh
[INFO commands] All selected scripts completed successfully
EOF

if bash "$verifier" \
    /workspace/docker-parent/scripts \
    "$collected_scripts" \
    "$runner_log" \
    docker yubikey >"$failure_log" 2>&1; then
    fail 'a final runner banner hid the missing git.sh completion'
fi
rg -q --fixed-strings 'alpine/git.sh' "$failure_log" || \
    fail 'missing-completion failure did not identify alpine/git.sh'

printf '%s\n' \
    '[INFO runner] Script completed successfully: /workspace/docker-parent/scripts/alpine/git.sh' \
    >> "$runner_log"

bash "$verifier" \
    /workspace/docker-parent/scripts \
    "$collected_scripts" \
    "$runner_log" \
    docker yubikey

printf '%s\n' 'Per-script Docker runner log verification passed.'
