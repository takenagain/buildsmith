#!/bin/bash

set -e

# Install required dependencies using homebrew
brew install curl git unzip coreutils xz
brew install --cask chromium

echo "Setting CHROME_EXECUTABLE variable"
export CHROME_EXECUTABLE="/Applications/Chromium.app/Contents/MacOS/Chromium"
echo "CHROME_EXECUTABLE=$CHROME_EXECUTABLE" | tee -a ~/.zshrc

# Install Flutter Version Manager (FVM)
curl -fsSL https://raw.githubusercontent.com/leoafarias/fvm/refs/heads/main/scripts/install.sh | bash

# Install Flutter versions
fvm install 2.8.1 # used for legacy KW mobile, soon to be removed
fvm install stable

# Add FVM to path if not already present
if ! grep -q "alias flutter=" ~/.zshrc; then
    printf '%s\n' \
        'export PATH="$HOME/.fvm/bin:$PATH"' \
        'alias flutter="fvm flutter"' >> ~/.zshrc
fi

# Install Java (OpenJDK)
brew install openjdk@21
sudo ln -sfn $(brew --prefix)/opt/openjdk@21/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk

# Set JAVA_HOME
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
echo "export JAVA_HOME=$JAVA_HOME" | tee -a ~/.zshrc
echo "export PATH=\$PATH:\$JAVA_HOME/bin" | tee -a ~/.zshrc
java -version

# Install Android tools
brew install android-platform-tools

# Install Android Studio
brew install --cask android-studio

echo "Finished installing Android Studio"
echo "Please open Android Studio and complete the setup wizard to install Android SDK"

# Run flutter doctor to ensure that everything is configured and installed
fvm global stable
yes | fvm flutter doctor --android-licenses
fvm flutter doctor -v

echo "Flutter installation completed for macOS"
echo "You may need to restart your terminal or run 'source ~/.zshrc' to apply all changes"
