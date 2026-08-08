#!/usr/bin/env bash

set -euo pipefail

# Arch ships Dart and FVM; FVM downloads Flutter stable from Flutter's official release channel.
sudo pacman -Syu --needed --noconfirm dart fvm chromium jdk-openjdk android-tools curl git unzip xz zip

export CHROME_EXECUTABLE="$(command -v chromium)"
if ! grep -Fqx "export CHROME_EXECUTABLE=${CHROME_EXECUTABLE}" "$HOME/.bashrc"; then
    echo "export CHROME_EXECUTABLE=${CHROME_EXECUTABLE}" >> "$HOME/.bashrc"
fi

fvm install stable
fvm global stable

accept_android_licenses() {
    local flutter_status

    set +e
    set +o pipefail
    yes | fvm flutter doctor --android-licenses
    flutter_status="${PIPESTATUS[1]}"
    set -o pipefail
    set -e

    return "$flutter_status"
}

accept_android_licenses
fvm flutter doctor -v
