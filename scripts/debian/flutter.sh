#!/bin/bash

set -e

sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
  libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64 \
  clang cmake git ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libstdc++-12-dev

echo "Installing chromium and setting CHROME_EXECUTABLE variable"
sudo snap install chromium
export CHROME_EXECUTABLE=/snap/bin/chromium
echo "CHROME_EXECUTABLE=$CHROME_EXECUTABLE" | tee -a ~/.bashrc
    
curl -fsSL https://raw.githubusercontent.com/leoafarias/fvm/refs/heads/main/scripts/install.sh | bash

fvm install 3.16.9
fvm install 3.24.5
fvm install 2.8.1
fvm install stable

if ! grep -q "alias flutter=" ~/.bashrc; then
    printf '%s\n' \
        'export PATH="$HOME/.fvm/bin:$PATH"' \
        'alias flutter="fvm flutter"' >> ~/.bashrc
fi

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install --lts
nvm use --lts

sudo apt install -y openjdk-21-jdk openjdk-21-jre android-tools-adb android-tools-fastboot
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin
java -version

# Android SDK
wget -c "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
sudo mkdir -p /opt/android-sdk
sudo chown -R $USER:$USER /opt/android-sdk
unzip commandlinetools-linux-11076708_latest.zip -d /opt/android-sdk
export ANDROID_HOME=/opt/android-sdk
echo "export ANDROID_HOME=/opt/android-sdk" | tee -a ~/.bashrc
$ANDROID_HOME/cmdline-tools/bin/sdkmanager --install "cmdline-tools;latest" --sdk_root=$ANDROID_HOME
$ANDROID_HOME/cmdline-tools/bin/sdkmanager "platform-tools" "platforms;android-35" --sdk_root=$ANDROID_HOME

# Android Studio
wget -c "https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2024.2.1.12/android-studio-2024.2.1.12-linux.tar.gz"
sudo mkdir -p /opt/android-studio
sudo chown -R $USER:$USER /opt/android-studio
tar -xzf android-studio-2024.2.1.12-linux.tar.gz -C /opt
mkdir -p "$HOME"/.local/share/applications
cat >"$HOME"/.local/share/applications/android-studio.desktop <<-EOF
		[Desktop Entry]
		Version=2024.2.1.12
		Type=Application
		Name=Android Studio
		Exec="/opt/android-studio/bin/studio.sh" %f
		Icon=/opt/android-studio/bin/studio.png
		Categories=Development;IDE;
		Terminal=false
		StartupNotify=true
		StartupWMClass=android-studio
	EOF
chmod +x "$HOME"/.local/share/applications/android-studio.desktop
echo "Finished installing Android Studio"

# Run flutter doctor to ensure that everything is configured and installed
fvm global stable
yes | fvm flutter doctor --android-licenses
fvm flutter doctor -v
