#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'
if ($PSNativeCommandUseErrorActionPreference -ne $true) {
    $PSNativeCommandUseErrorActionPreference = $true
}

choco install -y yubikey-manager openssh
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent

$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}

if ($env:CI -ne '1') {
    Write-Host 'Please insert your YubiKey and press Enter to continue...'
    Read-Host
    ssh-keygen -t ed25519-sk
}

$sshConfig = Join-Path $sshDir 'config'
if (!(Test-Path $sshConfig)) {
    New-Item -ItemType File -Path $sshConfig | Out-Null
}
$identityLine = 'IdentityFile ~/.ssh/id_ed25519_sk'
if (!(Select-String -Path $sshConfig -Pattern ([regex]::Escape($identityLine)) -Quiet)) {
    Add-Content -Path $sshConfig -Value $identityLine
}

Write-Host 'YubiKey SSH-agent setup complete.'
