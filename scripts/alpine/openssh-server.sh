#!/bin/sh

set -e

# Install OpenSSH and related tools
apk add openssh iptables fail2ban

# Enable and start SSH service
rc-update add sshd
rc-service sshd start

# Get SSH key
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
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i "s/#\?Port.*/Port $ssh_port/" /etc/ssh/sshd_config

# Configure firewall
apk add iptables ip6tables
iptables -A INPUT -p tcp --dport $ssh_port -j ACCEPT
iptables-save > /etc/iptables/rules.v4

# Restart SSH service
rc-service sshd restart

echo "SSH has been configured successfully!"
