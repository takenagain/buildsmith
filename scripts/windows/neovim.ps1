#!/usr/bin/env pwsh

# Install Neovim and dependencies using chocolatey
choco install -y neovim fd ripgrep

# Install NvChad configuration
git clone https://github.com/takenagain/nvchad-config.git "$env:LOCALAPPDATA\nvim"

Write-Host "Neovim installation complete!"