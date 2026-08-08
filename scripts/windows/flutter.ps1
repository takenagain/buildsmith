#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

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

# Install the current stable Flutter channel.
fvm install stable
fvm global stable

# Install Android Studio using Chocolatey
choco install -y androidstudio

# Android Studio ships the supported JDK; use it before falling back to any
# system Java installation already available on the machine.
$javaHomeCandidates = @(
    (Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr')
)
$javaHome = $javaHomeCandidates |
    Where-Object { Test-Path (Join-Path $_ 'bin\java.exe') } |
    Select-Object -First 1
if (-not $javaHome) {
    $javaCommand = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($javaCommand) {
        $javaHome = Split-Path -Parent (Split-Path -Parent $javaCommand.Path)
    }
}
if (-not $javaHome -or -not (Test-Path (Join-Path $javaHome 'bin\java.exe'))) {
    throw 'Unable to locate a valid Android Studio or system Java installation.'
}
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHome, 'Machine')
$env:JAVA_HOME = $javaHome
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
