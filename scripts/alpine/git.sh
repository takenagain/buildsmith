#!/bin/sh

set -eu

sudo apk add --no-cache git openssh-client gnupg

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

git config --global gpg.format ssh
git config --global user.signingkey "$HOME/.ssh/id_ed25519_sk_rk.pub"
git config --global commit.gpgsign true
git config --global tag.gpgSign true

if ! grep -Fqx 'IdentityFile ~/.ssh/id_ed25519_sk_rk' "$HOME/.ssh/config"; then
    printf '%s\n' 'IdentityFile ~/.ssh/id_ed25519_sk_rk' >> "$HOME/.ssh/config"
fi
