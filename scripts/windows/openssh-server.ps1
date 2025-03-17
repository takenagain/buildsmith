#!/usr/bin/env pwsh

# Install OpenSSH Server and Client features
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start and configure OpenSSH Server
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Get SSH public key from user
$sshKey = Read-Host -Prompt 'Paste your SSH public key'

# Set up authorized_keys
$sshPath = "$env:USERPROFILE\.ssh"
if (!(Test-Path $sshPath)) {
    New-Item -Type Directory -Path $sshPath
}

$authorizedKeysPath = "$sshPath\authorized_keys"
Add-Content -Path $authorizedKeysPath -Value $sshKey

# Set correct permissions
icacls $sshPath /inheritance:r
icacls $sshPath /grant:r "${env:USERNAME}:(OI)(CI)F"
icacls $authorizedKeysPath /inheritance:r
icacls $authorizedKeysPath /grant:r "${env:USERNAME}:F"

# Configure sshd
$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"
$config = Get-Content $sshdConfigPath

# Get desired port
$sshPort = Read-Host -Prompt 'Enter desired SSH port (default 22)'
if ([string]::IsNullOrWhiteSpace($sshPort)) {
    $sshPort = "22"
}

# Update configuration
$config = $config -replace "#?\s*Port.*", "Port $sshPort"
$config = $config -replace "#?\s*PasswordAuthentication.*", "PasswordAuthentication no"
$config = $config -replace "#?\s*PermitRootLogin.*", "PermitRootLogin no"

Set-Content -Path $sshdConfigPath -Value $config

# Configure Windows Firewall
Remove-NetFirewallRule -Name "SSH-Server-In-TCP" -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "SSH-Server-In-TCP" -DisplayName "SSH Server (port $sshPort)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $sshPort

# Restart the service
Restart-Service sshd

Write-Host "SSH Server has been configured successfully!"