#!/bin/sh

set -eu

# Alpine has neovim in its repositories
sudo apk add neovim python3 py3-pip fd

# Install Homebrew (optional, if you want the latest neovim)
# Note: Homebrew on Alpine is experimental
if [ "${CI:-0}" != "1" ] && [ -t 0 ]; then
    echo "Do you want to install Homebrew for the latest Neovim? (y/N): "
    read install_homebrew
    if [ "$install_homebrew" = "y" ] || [ "$install_homebrew" = "Y" ]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install neovim
    fi
fi

# Clone NvChad config
sudo apk add git
mkdir -p "$HOME/.config"
git clone https://github.com/takenagain/nvchad-config.git ~/.config/nvim

echo "Neovim has been installed with NvChad configuration."
