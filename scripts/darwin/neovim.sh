#!/bin/bash

# Install Neovim using Homebrew
brew install neovim

# Install Python dependencies
brew install python@3 fd

# Install Python packages
pip3 install pynvim

# Clone Neovim configuration
git clone https://github.com/takenagain/nvchad-config.git ~/.config/nvim
