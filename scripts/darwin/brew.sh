#!/bin/bash

# Check if Homebrew is installed, install if not
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH for Apple Silicon Macs if needed
  if [[ $(uname -m) == 'arm64' ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# Update Homebrew and upgrade packages
brew update && brew upgrade

# Install command line tools
brew install htop curl git python3 tmux vim gcc cmake llvm

# Install development tools
brew install --cask visual-studio-code

# Install browsers
brew install --cask firefox google-chrome

# Yubikey related packages
brew install pam_u2f ykman

# Install applications equivalent to the snap versions
brew install --cask bitwarden
brew install --cask obsidian
brew install --cask vlc
brew install --cask vscodium  # codium equivalent
brew install go
brew install --cask remmina  # or alternative: brew install --cask royal-tsx
brew install --cask brave-browser
brew install --cask telegram

# Install flatpak equivalent - there's no direct equivalent but homebrew cask serves a similar purpose
# No need to add repositories like flatpak

# Create a shortcut to install GUI apps
echo "Additional GUI applications can be installed with:"
echo "brew install --cask app-name"

# Make the script executable
chmod +x "$0"
