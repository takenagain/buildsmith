#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Please run brew.sh first."
    exit 1
fi

# Install ProtonVPN
echo "Installing ProtonVPN..."
brew install --cask protonvpn

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo "ProtonVPN has been successfully installed."
    echo "You can now launch it from your Applications folder."
else
    echo "Error: ProtonVPN installation failed."
    exit 1
fi
