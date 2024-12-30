#!/bin/bash

set -e

sudo apt install openssh-server ufw fail2ban
sudo systemctl enable ssh --now

read -p "Paste your SSH public key: " ssh_key

# Save SSH key
mkdir -p ~/.ssh
echo "$ssh_key" >> ~/.ssh/authorized_keys
sudo chmod 700 ~/.ssh
sudo chmod 600 ~/.ssh/authorized_keys

# Get desired SSH port
read -p "Enter desired SSH port (default 22): " ssh_port
ssh_port=${ssh_port:-22}

# Configure sshd
sudo sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i "s/#\?Port.*/Port $ssh_port/" /etc/ssh/sshd_config

# Configure firewall
sudo ufw allow $ssh_port/tcp comment "SSH Server"
sudo ufw enable

# Restart SSH service
sudo systemctl restart sshd
sudo systemctl restart ssh

echo "SSH has been configured successfully!"