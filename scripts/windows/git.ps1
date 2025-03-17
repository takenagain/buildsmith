#!/usr/bin/env pwsh

# Install Git and YubiKey tools using Chocolatey
choco install -y git yubikey-manager openssh

# Install Windows OpenSSH (if not already installed)
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start OpenSSH Authentication Agent
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent

# Create SSH directory if it doesn't exist
$sshDir = "$env:USERPROFILE\.ssh"
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir
    icacls $sshDir /inheritance:r
    icacls $sshDir /grant:r "${env:USERNAME}:(OI)(CI)F"
}

# Generate SSH key from YubiKey
Write-Host "Please insert your YubiKey and press Enter to continue..."
Read-Host
ssh-keygen -t ed25519-sk

# Configure Git
git config --global gpg.format ssh
git config --global user.signingkey "$env:USERPROFILE\.ssh\id_ed25519_sk.pub"
git config --global commit.gpgsign true
git config --global tag.gpgSign true

# Add key to SSH config
$sshConfig = "$env:USERPROFILE\.ssh\config"
if (!(Test-Path $sshConfig)) {
    New-Item -ItemType File -Path $sshConfig
}
Add-Content -Path $sshConfig -Value "IdentityFile ~/.ssh/id_ed25519_sk"

Write-Host "Git and YubiKey setup complete!"