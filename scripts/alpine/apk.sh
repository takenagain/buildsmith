#!/bin/sh

# Update system packages
apk update && apk upgrade

# Install basic packages
apk add htop curl git python3 py3-pip gcc g++ cmake clang llvm pam-u2f screen tmux vim

# Alpine doesn't have flatpak by default in its repositories
# If you need flatpak functionality, you would need to build it from source
# or use a different approach for installing applications

echo "Installing alternatives to snap packages..."

# For Bitwarden
apk add --no-cache curl
mkdir -p ~/.local/bin
curl -fsSL https://vault.bitwarden.com/download/?app=cli -o ~/.local/bin/bw
chmod +x ~/.local/bin/bw
echo "Bitwarden CLI installed. For the desktop app, consider using the web version."

# For Obsidian, VLC, VSCodium
echo "For Obsidian, VLC, and VSCodium, you can use AppImages or compile from source."
echo "Visit respective websites:"
echo "- Obsidian: https://obsidian.md/"
echo "- VLC: https://www.videolan.org/vlc/
curl -fsSL https://vault.bitwarden.com/download/?app=cli -o ~/.local/bin/bw
chmod +x ~/.local/bin/bw
echo "Bitwarden CLI installed. For the desktop app, consider using the web version."

# For Obsidian, VLC, VSCodium
echo "For Obsidian, VLC, and VSCodium, you can use AppImages or compile from source."
echo "Visit respective websites:"
echo "- Obsidian: https://obsidian.md/"
echo "- VLC: https://www.videolan.org/vlc/"
echo "- VSCodium: https://vscodium.com/"

# Go installation
apk add go

# Remmina
apk add remmina

# For Brave browser
echo "Brave browser: Use the official instructions from brave.com for Linux"
echo "Or use a compatible alternative like Firefox"
apk add firefox-esr

# For Telegram
apk add telegram-desktop

echo "Note: Some applications may require additional setup or may not be directly available on Alpine Linux."

"
echo "- VSCodium: https://vscodium.com/"

# Go installation
apk add go

# Remmina
apk add remmina

# For Brave browser
echo "Brave browser: Use the official instructions from brave.com for Linux"
echo "Or use a compatible alternative like Firefox"
apk add firefox-esr

# For Telegram
apk add telegram-desktop

echo "Note: Some applications may require additional setup or may not be directly available on Alpine Linux."

