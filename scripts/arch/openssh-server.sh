#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm openssh ufw fail2ban
sudo ssh-keygen -A

ssh_key="${SSH_PUBLIC_KEY:-}"
ssh_port="${SSH_PORT:-22}"
if [ -z "$ssh_key" ] && [ "${CI:-0}" != "1" ]; then
    read -r -p "Paste your SSH public key: " ssh_key
fi

if [ -n "$ssh_key" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    if ! grep -Fqx "$ssh_key" "$HOME/.ssh/authorized_keys"; then
        printf '%s\n' "$ssh_key" >> "$HOME/.ssh/authorized_keys"
    fi
    chmod 600 "$HOME/.ssh/authorized_keys"
fi

if [ -z "${SSH_PORT:-}" ] && [ "${CI:-0}" != "1" ]; then
    read -r -p "Enter desired SSH port (default 22): " ssh_port_input
    ssh_port="${ssh_port_input:-22}"
fi

sudo sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i -E 's/^#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
if sudo grep -qE '^#?Port ' /etc/ssh/sshd_config; then
    sudo sed -i -E "s/^#?Port .*/Port ${ssh_port}/" /etc/ssh/sshd_config
else
    printf 'Port %s\n' "$ssh_port" | sudo tee -a /etc/ssh/sshd_config >/dev/null
fi

if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    sudo systemctl enable --now sshd.service
else
    sudo mkdir -p /run/sshd
    sudo sshd -t
    sudo /usr/bin/sshd
fi

if sudo ufw allow "${ssh_port}/tcp" comment "SSH Server" >/dev/null 2>&1; then
    sudo ufw --force enable
fi

echo "SSH has been configured successfully on port ${ssh_port}."
