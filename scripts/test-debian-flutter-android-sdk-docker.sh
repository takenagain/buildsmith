#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/docker-validation-resources.sh
source "$repository_root/scripts/lib/docker-validation-resources.sh"
apparmor_namespace="buildsmith-flutter-validation-$$"
container_id=''

cleanup() {
    if [ -n "$container_id" ]; then
        docker rm --force "$container_id" >/dev/null 2>&1 || true
    fi

    docker run --pull=never --privileged --rm \
        --mount type=bind,src=/sys/kernel/security,dst=/sys/kernel/security \
        ubuntu:latest bash -eu -c \
        "rmdir /sys/kernel/security/apparmor/policy/namespaces/$apparmor_namespace" \
        >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [ ! -d /sys/kernel/security/apparmor/policy/namespaces ]; then
    echo "Flutter Snap validation requires an AppArmor policy namespace-capable host kernel." >&2
    exit 1
fi

docker run --pull=always --privileged --rm \
    --mount type=bind,src=/sys/kernel/security,dst=/sys/kernel/security \
    ubuntu:latest bash -eu -c \
    "mkdir /sys/kernel/security/apparmor/policy/namespaces/$apparmor_namespace"

container_id="$(
    docker run --pull=always --privileged --detach \
        "${buildsmith_docker_resource_args[@]}" \
        --cgroupns=private \
        --tmpfs /run \
        --tmpfs /run/lock \
        --mount "type=bind,src=${repository_root},dst=/workspace,readonly" \
        --mount type=bind,src=/sys/kernel/security,dst=/sys/kernel/security \
        --security-opt "apparmor=:$apparmor_namespace:unconfined" \
        --workdir /workspace \
        --env CI=1 \
        --env DEBIAN_FRONTEND=noninteractive \
        ubuntu:latest bash -c \
        'apt-get update && apt-get install -y --no-install-recommends systemd dbus dbus-user-session && touch /var/lib/buildsmith-systemd-bootstrap-ready && exec /lib/systemd/systemd'
)"

container_status=''
container_ready=0
for _ in $(seq 1 180); do
    container_status="$(docker inspect --format '{{.State.Status}}' "$container_id")"
    if [ "$container_status" = 'running' ] && \
        docker exec "$container_id" test -e /var/lib/buildsmith-systemd-bootstrap-ready >/dev/null 2>&1 && \
        docker exec "$container_id" \
            busctl --system status org.freedesktop.systemd1 >/dev/null 2>&1; then
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
    echo "Flutter Snap validation requires a private cgroup namespace." >&2
    exit 1
fi

docker exec -i "$container_id" bash -euo pipefail <<'CONTAINER_TEST'
export DEBIAN_FRONTEND=noninteractive

if ! busctl --system status org.freedesktop.systemd1 >/dev/null 2>&1; then
    echo "The system D-Bus is not connected to systemd PID 1." >&2
    exit 1
fi

apt-get update
apt-get install -y --no-install-recommends sudo ca-certificates curl

useradd --create-home --shell /bin/bash buildsmith
printf '%s\n' 'buildsmith ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/buildsmith
chmod 440 /etc/sudoers.d/buildsmith

buildsmith_home="$(getent passwd buildsmith | cut -d: -f6)"
buildsmith_uid="$(id -u buildsmith)"
install -d -m 700 -o buildsmith -g buildsmith "/run/user/$buildsmith_uid"

run_installer() {
    local log_file="$1"

    sudo -u buildsmith -H env \
        CI=1 \
        DEBIAN_FRONTEND=noninteractive \
        HOME="$buildsmith_home" \
        USER=buildsmith \
        XDG_RUNTIME_DIR="/run/user/$buildsmith_uid" \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        bash /workspace/scripts/debian/flutter.sh 2>&1 | tee "$log_file"
}

run_installer /tmp/buildsmith-flutter-android-sdk-first.log
bashrc_hash_after_first="$(sha256sum "$buildsmith_home/.bashrc" | cut -d ' ' -f1)"
run_installer /tmp/buildsmith-flutter-android-sdk-second.log
bashrc_hash_after_second="$(sha256sum "$buildsmith_home/.bashrc" | cut -d ' ' -f1)"

if [ "$bashrc_hash_after_first" != "$bashrc_hash_after_second" ]; then
    echo "A repeat Flutter installation changed shell initialization." >&2
    exit 1
fi

sudo -u buildsmith -H env \
    HOME="$buildsmith_home" \
    USER=buildsmith \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    bash -euo pipefail <<'USER_ASSERTIONS'
export FVM_INSTALL_DIR="$HOME/fvm"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$HOME/fvm/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

assert_bashrc_line_once() {
    local line="$1"
    local count

    count="$(grep -Fxc "$line" "$HOME/.bashrc" || true)"
    if [ "$count" -ne 1 ]; then
        printf 'Expected one bashrc line, found %s: %s\n' "$count" "$line" >&2
        return 1
    fi
}

assert_bashrc_line_once 'export CHROME_EXECUTABLE=/snap/bin/chromium'
assert_bashrc_line_once 'export FVM_INSTALL_DIR="$HOME/fvm"'
assert_bashrc_line_once 'export PATH="$HOME/fvm/bin:$PATH"'
assert_bashrc_line_once 'alias flutter="fvm flutter"'
assert_bashrc_line_once 'export ANDROID_HOME="$HOME/Android/Sdk"'
assert_bashrc_line_once \
    'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"'

test -x "$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager"
test -x "$HOME/Android/Sdk/platform-tools/adb"
test -f "$HOME/Android/Sdk/platforms/android-36/android.jar"
grep -Fqx 'AndroidVersion.ApiLevel=36' \
    "$HOME/Android/Sdk/platforms/android-36/source.properties"
test -x "$HOME/Android/Sdk/build-tools/37.0.0/aapt2"
grep -Fqx 'Pkg.Revision=37.0.0' \
    "$HOME/Android/Sdk/build-tools/37.0.0/source.properties"
test "$(stat -c %U:%G "$HOME/Android/Sdk")" = 'buildsmith:buildsmith'
"$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager" \
    --sdk_root="$ANDROID_HOME" --list_installed >/dev/null
"$HOME/Android/Sdk/platform-tools/adb" version >/dev/null
"$HOME/Android/Sdk/build-tools/37.0.0/aapt2" version >/dev/null

set +e
set +o pipefail
yes | fvm flutter doctor --android-licenses
flutter_status="${PIPESTATUS[1]}"
set -o pipefail
set -e
test "$flutter_status" -eq 0

bash --noprofile --rcfile "$HOME/.bashrc" -ic '
    test "$CHROME_EXECUTABLE" = /snap/bin/chromium
    env | grep -Fqx "CHROME_EXECUTABLE=/snap/bin/chromium"
    test "$ANDROID_HOME" = "$HOME/Android/Sdk"
    test "$(command -v sdkmanager)" = "$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager"
'
USER_ASSERTIONS
CONTAINER_TEST

printf '%s\n' 'Debian Flutter Android SDK license validation passed.'
