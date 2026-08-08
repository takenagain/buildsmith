#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm git openssh gnupg pinentry pcsclite ccid yubikey-manager

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
if ! grep -Fqx 'export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"' "$HOME/.bashrc"; then
    echo 'export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"' >> "$HOME/.bashrc"
fi

sudo systemctl enable --now pcscd.socket
gpgconf --launch gpg-agent

git config --global gpg.format ssh
git config --global user.signingkey "$HOME/.ssh/id_ed25519_sk_rk.pub"
git config --global commit.gpgsign true
git config --global tag.gpgSign true
if ! grep -Fqx 'IdentityFile ~/.ssh/id_ed25519_sk_rk' "$HOME/.ssh/config"; then
    echo 'IdentityFile ~/.ssh/id_ed25519_sk_rk' >> "$HOME/.ssh/config"
fi
