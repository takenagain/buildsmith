#!/usr/bin/env pwsh

# Install Docker Desktop using WinGet
winget install -e --id Docker.DockerDesktop

# Refresh environment variables
refreshenv

# Install WSL if not already installed
if (!(Get-Command wsl -ErrorAction SilentlyContinue)) {
    wsl --install
}

# Add current user to docker-users group
$group = "docker-users"
$user = $env:USERNAME
$members = net localgroup $group
if ($members -notcontains $user) {
    net localgroup $group $user /add
}

Write-Host "Docker Desktop installation complete!"
Write-Host "Please log out and log back in for the group changes to take effect."
Write-Host "After logging back in, start Docker Desktop from the Start menu."