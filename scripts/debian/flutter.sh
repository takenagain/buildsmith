#!/bin/bash

set -euo pipefail

sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
  libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64 \
  clang cmake git ninja-build pkg-config libgtk-3-dev \
  liblzma-dev g++ libsecret-1-dev libsecret-1-0

ensure_snapd() {
    local snapd_binary

    snapd_is_ready() {
        [ -S /run/snapd.socket ] || return 1
        timeout 5 snap changes >/dev/null 2>&1
    }

    if ! command -v snap >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y snapd squashfs-tools
    fi

    if snapd_is_ready; then
        return 0
    fi

    if [ "$(ps -p 1 -o comm= 2>/dev/null)" = 'systemd' ] && command -v systemctl >/dev/null 2>&1; then
        sudo systemctl daemon-reload
        sudo systemctl enable --now snapd.socket
    else
        snapd_binary="$(command -v snapd || printf '%s' /usr/lib/snapd/snapd)"
        sudo "$snapd_binary" >/tmp/snapd.log 2>&1 &
    fi

    for _ in $(seq 1 30); do
        if snapd_is_ready; then
            return 0
        fi
        sleep 1
    done

    echo "snapd did not become ready" >&2
    return 1
}

echo "Installing chromium and setting CHROME_EXECUTABLE variable"
ensure_snapd
sudo env -u DBUS_SESSION_BUS_ADDRESS \
    DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket \
    snap wait system seed.loaded
snap_install() {
    sudo env -u DBUS_SESSION_BUS_ADDRESS \
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket \
        snap install "$@"
}

snap_install chromium
export CHROME_EXECUTABLE=/snap/bin/chromium
if ! grep -Fqx 'export CHROME_EXECUTABLE=/snap/bin/chromium' "$HOME/.bashrc" 2>/dev/null; then
    printf '%s\n' 'export CHROME_EXECUTABLE=/snap/bin/chromium' >> "$HOME/.bashrc"
fi
    
export FVM_INSTALL_DIR="$HOME/fvm"
installer_tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/buildsmith-flutter.XXXXXX")"
fvm_installer="$installer_tmpdir/fvm-install.sh"
trap 'rm -rf "$installer_tmpdir"' EXIT
curl -fsSL --retry 3 --retry-all-errors -o "$fvm_installer" \
  https://fvm.app/install.sh
bash "$fvm_installer"
export PATH="$HOME/fvm/bin:$PATH"

if ! grep -Fqx 'export FVM_INSTALL_DIR="$HOME/fvm"' "$HOME/.bashrc" 2>/dev/null; then
    printf '%s\n' 'export FVM_INSTALL_DIR="$HOME/fvm"' >> "$HOME/.bashrc"
fi
if ! grep -Fqx 'export PATH="$HOME/fvm/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    printf '%s\n' 'export PATH="$HOME/fvm/bin:$PATH"' >> "$HOME/.bashrc"
fi
if ! grep -Fqx 'alias flutter="fvm flutter"' "$HOME/.bashrc" 2>/dev/null; then
    printf '%s\n' 'alias flutter="fvm flutter"' >> "$HOME/.bashrc"
fi

fvm install stable
fvm global stable

sudo apt install -y default-jdk android-tools-adb android-tools-fastboot

# Android Studio's Snap channel tracks the supported current release.
snap_install android-studio --classic

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

export ANDROID_HOME="$HOME/Android/Sdk"
android_command_line_tools_version='23.0'
android_command_line_tools_build='16111833'
android_command_line_tools_sha256='0877a1d048fe4a24efe2eff536ca4223f7adeb58648bb81909d33c446918cfa8'
android_command_line_tools_dir="$ANDROID_HOME/cmdline-tools/latest"

if [ ! -x "$android_command_line_tools_dir/bin/sdkmanager" ] || \
    ! grep -Fqx "Pkg.Revision=$android_command_line_tools_version" \
        "$android_command_line_tools_dir/source.properties" 2>/dev/null; then
    android_command_line_tools_archive="$installer_tmpdir/commandlinetools.zip"
    android_command_line_tools_extract_dir="$installer_tmpdir/android-command-line-tools"
    android_command_line_tools_url="https://dl.google.com/android/repository/commandlinetools-linux-${android_command_line_tools_build}_latest.zip"

    curl -fsSL --retry 3 --retry-all-errors \
        -o "$android_command_line_tools_archive" \
        "$android_command_line_tools_url"
    printf '%s  %s\n' \
        "$android_command_line_tools_sha256" \
        "$android_command_line_tools_archive" | sha256sum --check -
    unzip -q "$android_command_line_tools_archive" \
        -d "$android_command_line_tools_extract_dir"
    grep -Fqx "Pkg.Revision=$android_command_line_tools_version" \
        "$android_command_line_tools_extract_dir/cmdline-tools/source.properties"

    install -d "$ANDROID_HOME/cmdline-tools"
    rm -rf "$android_command_line_tools_dir"
    mv "$android_command_line_tools_extract_dir/cmdline-tools" \
        "$android_command_line_tools_dir"
fi

export PATH="$android_command_line_tools_dir/bin:$ANDROID_HOME/platform-tools:$PATH"
if ! grep -Fqx 'export ANDROID_HOME="$HOME/Android/Sdk"' "$HOME/.bashrc" 2>/dev/null; then
    printf '%s\n' 'export ANDROID_HOME="$HOME/Android/Sdk"' >> "$HOME/.bashrc"
fi
if ! grep -Fqx 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' \
    "$HOME/.bashrc" 2>/dev/null; then
    printf '%s\n' \
        'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' \
        >> "$HOME/.bashrc"
fi

install_android_sdk_packages() {
    local sdkmanager_status

    set +e
    set +o pipefail
    yes | "$android_command_line_tools_dir/bin/sdkmanager" \
        --sdk_root="$ANDROID_HOME" \
        'platform-tools' \
        'platforms;android-36' \
        'build-tools;37.0.0'
    sdkmanager_status="${PIPESTATUS[1]}"
    set -o pipefail
    set -e

    return "$sdkmanager_status"
}

# Flutter's stable setup recommends API 36; use it with the latest stable Build-Tools.
install_android_sdk_packages

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
