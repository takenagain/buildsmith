#!/bin/bash

set -e

# Install OpenSSH and fail2ban via Homebrew
brew install openssh fail2ban

# Enable SSH service
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist

read -p "Paste your SSH public key: " ssh_key

# Save SSH key
mkdir -p ~/.ssh
echo "$ssh_key" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Get desired SSH port
read -p "Enter desired SSH port (default 22): " ssh_port
ssh_port=${ssh_port:-22}

# Configure sshd
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i '' 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i '' 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i '' "s/#\?Port.*/Port $ssh_port/" /etc/ssh/sshd_config

# Configure macOS firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /usr/sbin/sshd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Configure fail2ban
sudo cp /usr/local/etc/fail2ban/jail.conf /usr/local/etc/fail2ban/jail.local
sudo sed -i '' 's/^#\[sshd\]/\[sshd\]/' /usr/local/etc/fail2ban/jail.local
sudo sed -i '' '/^\[sshd\]/a enabled = true' /usr/local/etc/fail2ban/jail.local

# Restart SSH service
sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist

# Start fail2ban service
brew services start fail2ban

echo "SSH has been configured successfully!"
