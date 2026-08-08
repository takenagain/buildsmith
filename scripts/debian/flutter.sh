#!/bin/bash

set -euo pipefail

sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
  libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64 \
  clang cmake git ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libstdc++-dev libsecret-1-dev libsecret-1-0

echo "Installing chromium and setting CHROME_EXECUTABLE variable"
sudo snap install chromium
export CHROME_EXECUTABLE=/snap/bin/chromium
echo "CHROME_EXECUTABLE=$CHROME_EXECUTABLE" | tee -a ~/.bashrc
    
curl -fsSL https://raw.githubusercontent.com/leoafarias/fvm/refs/heads/main/scripts/install.sh | bash
export PATH="$HOME/.fvm/bin:$PATH"

fvm install stable

if ! grep -q "alias flutter=" ~/.bashrc; then
    printf '%s\n' \
        'export PATH="$HOME/.fvm/bin:$PATH"' \
        'alias flutter="fvm flutter"' >> ~/.bashrc
fi

sudo apt install -y default-jdk android-tools-adb android-tools-fastboot

# Android Studio's Snap channel tracks the supported current release.
sudo snap install android-studio --classic

echo "Finished installing Android Studio"

resolve_java_home() {
    local candidate java_path

    for candidate in \
        /snap/android-studio/current/android-studio/jbr \
        /opt/android-studio/jbr \
        "$HOME/.local/share/Google"/AndroidStudio*/jbr; do
        if [ -x "$candidate/bin/java" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    if command -v java >/dev/null 2>&1; then
        java_path="$(readlink -f "$(command -v java)")"
        candidate="$(dirname "$(dirname "$java_path")")"
        if [ -x "$candidate/bin/java" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    echo "Unable to locate a valid Android Studio or system Java installation." >&2
    return 1
}

export JAVA_HOME="$(resolve_java_home)"
export PATH="$JAVA_HOME/bin:$PATH"
printf 'Using JAVA_HOME=%s\n' "$JAVA_HOME"
java -version

# Run flutter doctor to ensure that everything is configured and installed
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
