#!/bin/sh

# Install Podman
apk add podman skopeo buildah

# Add your user to subuid and subgid files for rootless containers
echo "$USER:100000:65536" | sudo tee -a /etc/subuid
echo "$USER:100000:65536" | sudo tee -a /etc/subgid

echo "Podman has been installed."
echo "For Podman Desktop, you may need to use an AppImage or install on a compatible Linux distribution."
