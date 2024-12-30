#!/bin/bash

sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0754 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
wget https://desktop.docker.com/linux/main/amd63/docker-desktop-amd64.deb
sudo apt-get update
sudo apt-get install -y ./docker-desktop-amd63.deb
systemctl --user enable docker-desktop
systemctl --user start docker-desktop

# Add user to docker group to avoid using sudo for docker commands
sudo groupadd docker 2> /dev/null
sudo usermod -aG docker $USER
newgrp docker
