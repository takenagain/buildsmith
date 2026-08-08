#!/bin/bash

set -euo pipefail

# Install required dependencies using homebrew
brew install curl git unzip coreutils xz
brew install --cask chromium

echo "Setting CHROME_EXECUTABLE variable"
export CHROME_EXECUTABLE="/Applications/Chromium.app/Contents/MacOS/Chromium"
echo "CHROME_EXECUTABLE=$CHROME_EXECUTABLE" | tee -a ~/.zshrc

# Install Flutter Version Manager (FVM)
export FVM_INSTALL_DIR="$HOME/fvm"
fvm_installer="$(mktemp "${TMPDIR:-/tmp}/fvm-install.XXXXXX")"
trap 'rm -f "$fvm_installer"' EXIT
curl -fsSL --retry 3 --retry-all-errors -o "$fvm_installer" \
    https://fvm.app/install.sh
bash "$fvm_installer"
export PATH="$HOME/fvm/bin:$PATH"
if ! grep -Fqx 'export FVM_INSTALL_DIR="$HOME/fvm"' "$HOME/.zshrc" 2>/dev/null; then
    printf '%s\n' 'export FVM_INSTALL_DIR="$HOME/fvm"' >> "$HOME/.zshrc"
fi
if ! grep -Fqx 'export PATH="$HOME/fvm/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
    printf '%s\n' 'export PATH="$HOME/fvm/bin:$PATH"' >> "$HOME/.zshrc"
fi
if ! grep -Fqx 'alias flutter="fvm flutter"' "$HOME/.zshrc" 2>/dev/null; then
    printf '%s\n' 'alias flutter="fvm flutter"' >> "$HOME/.zshrc"
fi
fvm stable

# Install Android SDK and the current Homebrew JDK channel.
brew install openjdk android-platform-tools
brew install --cask android-studio

resolve_java_home() {
    local candidate

    for candidate in \
        "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
        "$HOME/Library/Application Support/Google"/AndroidStudio*/jbr/Contents/Home \
        "$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home"; do
        if [ -x "$candidate/bin/java" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    if [ -x /usr/libexec/java_home ]; then
        candidate="$(/usr/libexec/java_home)"
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
printf 'export JAVA_HOME="%s"\n' "$JAVA_HOME" | tee -a ~/.zshrc
printf 'export PATH="$PATH:$JAVA_HOME/bin"\n' | tee -a ~/.zshrc
java -version
echo "Finished installing Android Studio"
echo "Please open Android Studio and complete the setup wizard to install Android SDK"

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

echo "Flutter installation completed for macOS"
echo "You may need to restart your terminal or run 'source ~/.zshrc' to apply all changes"
