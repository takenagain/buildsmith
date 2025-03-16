#!/bin/sh

set -e

# Install dependencies
apk add curl git unzip xz zip bash

# Flutter requires glibc which is not available in Alpine by default
echo "Flutter requires glibc which Alpine Linux doesn't provide by default."
echo "You have two options:"

echo "1. Use a glibc-enabled Alpine image (not standard)"
echo "2. Compile Flutter apps in a container with glibc support"

# If you want to proceed with option 1:
echo "Do you want to install glibc compatibility layer? (y/N): "
read install_glibc
if [ "$install_glibc" = "y" ] || [ "$install_glibc" = "Y" ]; then
    # Alpine glibc compatibility layer
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.34-r0/glibc-2.34-r0.apk
    apk add --no-cache glibc-2.34-r0.apk

    # Install Flutter via FVM
    curl -fsSL https://raw.githubusercontent.com/leoafarias/fvm/refs/heads/main/scripts/install.sh | bash
    
    export PATH="$HOME/.fvm/bin:$PATH"
    echo 'export PATH="$HOME/.fvm/bin:$PATH"' >> ~/.profile
    echo 'alias flutter="fvm flutter"' >> ~/.profile
    
    fvm install stable
    fvm global stable
    
    # Install JDK for Android development
    apk add openjdk17
    
    echo "Please note that Flutter on Alpine may encounter unexpected issues."
    echo "For proper Flutter development, consider using Ubuntu or Debian."
else
    echo "Not installing glibc. Flutter will not function properly on this system."
    echo "Consider using a container or VM with a glibc-based distribution for Flutter development."
fi
