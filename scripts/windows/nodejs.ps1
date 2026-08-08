#!/usr/bin/env pwsh

# Install NVM for Windows using Chocolatey
choco install -y nvm.portable

# Refresh environment variables
refreshenv

# Install and use LTS version of Node.js
nvm install lts
nvm use lts

# Update npm and install global packages
npm install -g npm@latest
npm install -g npm-check-updates

Write-Host "Node.js environment setup complete!"
