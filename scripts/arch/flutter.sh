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
yes | fvm flutter doctor --android-licenses
fvm flutter doctor -v
