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

brew update && brew upgrade

# Install command line tools
brew install htop curl git python3 tmux vim gcc cmake llvm

# Yubikey related packages
brew install pam-u2f ykman

# Install applications equivalent to the snap versions
brew install --cask bitwarden
brew install --cask obsidian
brew install --cask vlc
brew install --cask visual-studio-code
brew install --cask vscodium 
brew install go
brew install --cask firefox google-chrome
brew install --cask brave-browser
brew install --cask telegram
