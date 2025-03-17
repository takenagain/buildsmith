#!/usr/bin/env pwsh

# Check if chocolatey is installed, install if not
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install Python and basic tools
choco install -y python

# Add Python scripts to PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install pipx
python -m pip install --user pipx
python -m pipx ensurepath
pipx install poetry

# Install pyenv-win
choco install -y pyenv-win

# Refresh environment variables
refreshenv

# Install Python versions
pyenv install 3.12.0
pyenv install 3.11.0
pyenv install 3.10.0
pyenv global 3.11.0

# Install modern Python tooling
Invoke-WebRequest -Uri https://astral.sh/uv/install.ps1 -UseBasicParsing | Invoke-Expression
Invoke-WebRequest -Uri https://rye.astral.sh/get | Invoke-Expression

Write-Host "Python environment setup complete!"