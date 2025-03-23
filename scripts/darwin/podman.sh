#!/bin/bash

# Install podman using Homebrew
brew install podman podman-compose

# Initialize podman machine (creates a VM for running containers)
podman machine init
podman machine start

# Install Podman Desktop (via Homebrew cask)
brew install --cask podman-desktop

echo "Podman and Podman Desktop have been installed successfully"
