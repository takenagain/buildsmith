#!/bin/bash

# Script to install common Gnome extensions

set -e

echo "Installing Gnome Shell extensions..."

# Check if gnome-shell-extension-manager is installed
if ! command -v gnome-extension-manager &> /dev/null; then
    echo "Installing gnome-shell-extension-manager..."
    sudo apt-get update
    sudo apt-get install -y gnome-shell-extension-manager
fi

# Define extensions to install with their UUID
EXTENSIONS=(
    "vitals@CoreCoding.com"                  # Vitals
    "tiling-assistant@leleat-on-github"      # Tiling Assistant
    "wallpaper-switcher@bernhard.hauer.name" # Wallpaper Switcher
    "sound-output-device-chooser@kgshank.net" # Sound Input & Output Device Chooser
    "ddterm@amezin.github.com"               # ddterm
)

# Install each extension
for ext in "${EXTENSIONS[@]}"; do
    echo "Installing extension: $ext"
    gnome-extensions install "$ext" || echo "Failed to install $ext, may already be installed"
    gnome-extensions enable "$ext" || echo "Failed to enable $ext"
done

echo "Gnome extensions installation complete!"
echo "You may need to restart the GNOME Shell (Alt+F2, r, Enter) for changes to take effect."
