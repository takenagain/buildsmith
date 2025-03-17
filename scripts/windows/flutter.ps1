#!/usr/bin/env pwsh

# Install required dependencies
choco install -y git unzip curl
winget install -e --id Google.Chrome

# Set Chrome as the default browser for Flutter development
$env:CHROME_EXECUTABLE = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
[System.Environment]::SetEnvironmentVariable('CHROME_EXECUTABLE', $env:CHROME_EXECUTABLE, 'User')

# Install Flutter Version Manager (FVM)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/leoafarias/fvm/main/packages/cli/scripts/install.ps1" -UseBasicParsing | Invoke-Expression

# Add FVM to PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install Flutter versions
fvm install 2.8.1  # used for legacy KW mobile, soon to be removed
fvm install stable
fvm global stable

# Install Android Studio using Chocolatey
choco install -y androidstudio

# Install OpenJDK 21
choco install -y openjdk21

# Set JAVA_HOME
$javaHome = "C:\Program Files\OpenJDK\openjdk-21"
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHome, 'Machine')
$env:Path = "$javaHome\bin;" + $env:Path
[System.Environment]::SetEnvironmentVariable('Path', $env:Path, 'Machine')

# Refresh environment
refreshenv

# Accept Android licenses
Write-Host "Accepting Android licenses..."
fvm flutter doctor --android-licenses

# Run flutter doctor
fvm flutter doctor -v

Write-Host "Flutter installation completed for Windows"
Write-Host "Please complete Android Studio setup manually when it launches"