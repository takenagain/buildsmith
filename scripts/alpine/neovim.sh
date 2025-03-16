#!/bin/sh

# Alpine has neovim in its repositories
apk add neovim python3 py3-pip fd

# Install Homebrew (optional, if you want the latest neovim)
# Note: Homebrew on Alpine is experimental
echo "Do you want to install Homebrew for the latest Neovim? (y/N): "
read install_homebrew
if [ "$install_homebrew" = "y" ] || [ "$install_homebrew" = "Y" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew install neovim
fi

# Clone NvChad config
apk add git
git clone https://github.com/takenagain/nvchad-config.git ~/.config/nvim

echo "Neovim has been installed with NvChad configuration."
