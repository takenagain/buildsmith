#!/bin/sh

set -eu

sudo apk add --no-cache openssh iptables ip6tables
sudo ssh-keygen -A

ssh_key="${SSH_PUBLIC_KEY:-}"
ssh_port="${SSH_PORT:-22}"
if [ -z "$ssh_key" ] && [ "${CI:-0}" != "1" ]; then
    printf 'Paste your SSH public key: '
    read -r ssh_key
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
    printf 'Enter desired SSH port (default 22): '
    read -r ssh_port_input
    ssh_port="${ssh_port_input:-22}"
fi

sudo sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i -E 's/^#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
if grep -qE '^#?Port ' /etc/ssh/sshd_config; then
    sudo sed -i -E "s/^#?Port .*/Port ${ssh_port}/" /etc/ssh/sshd_config
else
    printf 'Port %s\n' "$ssh_port" | sudo tee -a /etc/ssh/sshd_config >/dev/null
fi

sudo mkdir -p /etc/iptables
sudo iptables -A INPUT -p tcp --dport "$ssh_port" -j ACCEPT
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'

if command -v rc-update >/dev/null 2>&1 && [ "${CI:-0}" != "1" ]; then
    sudo rc-update add sshd default
    sudo rc-service sshd restart
else
    sudo mkdir -p /run/sshd
    sudo /usr/sbin/sshd -t
    sudo /usr/sbin/sshd
fi

echo "SSH has been configured successfully on port ${ssh_port}."
