#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm openssh ufw fail2ban
sudo systemctl enable --now sshd

read -r -p "Paste your SSH public key: " ssh_key
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
printf '%s\n' "$ssh_key" >> "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"

read -r -p "Enter desired SSH port (default 22): " ssh_port
ssh_port="${ssh_port:-22}"

sudo sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i "s/#\?Port.*/Port ${ssh_port}/" /etc/ssh/sshd_config
sudo ufw allow "${ssh_port}/tcp" comment "SSH Server"
sudo ufw --force enable
sudo systemctl restart sshd
