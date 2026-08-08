#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Install NVM for Windows using Chocolatey
choco install -y nvm.portable

# Refresh environment variables
refreshenv

# Install and use the latest available Node.js release.
nvm install latest
nvm use latest

# Update npm and install global packages
npm install -g npm@latest
npm install -g npm-check-updates

Write-Host "Node.js environment setup complete!"
