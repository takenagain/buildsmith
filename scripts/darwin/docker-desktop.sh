#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew is required but not installed. Please run the brew.sh script first."
  exit 1
fi

# Install Docker Desktop using Homebrew cask
echo "Installing Docker Desktop..."
brew install --cask docker

# Launch Docker Desktop
echo "Starting Docker Desktop..."
open -a Docker

echo "Waiting for Docker to start..."
sleep 10

# Verify Docker installation
echo "Verifying Docker installation..."
if command -v docker &> /dev/null; then
  echo "Docker has been installed successfully!"
  docker --version
else
  echo "Docker installation may not have completed properly. Please check Docker Desktop."
fi

echo "Note: You may need to start Docker Desktop manually for the first time to complete setup."
echo "Docker Desktop has been installed. You may need to log out and log back in for group changes to take effect."
