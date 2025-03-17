#!/usr/bin/env pwsh

# Install Chocolatey if not installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install basic development tools
choco install -y `
    mingw `
    cmake `
    llvm `
    golang `
    curl `
    vscode `
    bitwarden `
    obsidian `
    vlc `
    vscodium `
    brave `
    telegram

# Install Windows Terminal (recommended for Windows development)
winget install -e --id Microsoft.WindowsTerminal

# Install PowerShell 7 (if not already installed)
winget install -e --id Microsoft.PowerShell

Write-Host "Basic development tools installation complete!"