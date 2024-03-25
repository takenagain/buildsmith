#!/bin/bash

sudo apt -y install podman

flatpak install -y flathub io.podman_desktop.PodmanDesktop

# Add Docker's official GPG key:
sudo apt-get update 
sudo apt-get -y install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

wget https://desktop.docker.com/linux/main/amd64/139021/docker-desktop-4.28.0-amd64.deb
sudo apt install -y docker-desktop-4.28.0-amd64.deb

echo "
[registries.search]
registries = ['docker.io']" | sudo tee -a /etc/containers/registries.conf
