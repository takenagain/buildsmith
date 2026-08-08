#!/bin/bash

set -e

sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
  libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64 \
  clang cmake git ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libstdc++-12-dev libsecret-1-dev libsecret-1-0

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

sudo apt install -y openjdk-21-jdk openjdk-21-jre android-tools-adb android-tools-fastboot
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin
java -version

# Android Studio's Snap channel tracks the supported current release.
sudo snap install android-studio --classic

echo "Finished installing Android Studio"

# Run flutter doctor to ensure that everything is configured and installed
fvm global stable
yes | fvm flutter doctor --android-licenses
fvm flutter doctor -v
