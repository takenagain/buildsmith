#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'
if ($PSNativeCommandUseErrorActionPreference -ne $true) {
    $PSNativeCommandUseErrorActionPreference = $true
}

choco install -y git openssh

$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}

git config --global gpg.format ssh
git config --global user.signingkey (Join-Path $sshDir 'id_ed25519_sk.pub')
git config --global commit.gpgsign true
git config --global tag.gpgSign true

$sshConfig = Join-Path $sshDir 'config'
if (!(Test-Path $sshConfig)) {
    New-Item -ItemType File -Path $sshConfig | Out-Null
}
$identityLine = 'IdentityFile ~/.ssh/id_ed25519_sk'
if (!(Select-String -Path $sshConfig -Pattern ([regex]::Escape($identityLine)) -Quiet)) {
    Add-Content -Path $sshConfig -Value $identityLine
}
