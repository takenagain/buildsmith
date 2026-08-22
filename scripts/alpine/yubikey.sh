#!/bin/sh

set -eu

sudo apk add --no-cache ccid gnupg gnupg-scdaemon pinentry pcsc-lite yubikey-manager

mkdir -p "$HOME/.gnupg" "$HOME/.ssh"
chmod 700 "$HOME/.gnupg" "$HOME/.ssh"

if ! grep -Fqx 'enable-ssh-support' "$HOME/.gnupg/gpg-agent.conf" 2>/dev/null; then
    printf '%s\n' 'enable-ssh-support' >> "$HOME/.gnupg/gpg-agent.conf"
fi
if ! grep -Fqx 'pinentry-program /usr/bin/pinentry' "$HOME/.gnupg/gpg-agent.conf" 2>/dev/null; then
    printf '%s\n' 'pinentry-program /usr/bin/pinentry' >> "$HOME/.gnupg/gpg-agent.conf"
fi

profile="$HOME/.profile"
socket_line='export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"'
launch_line='gpgconf --launch gpg-agent'
if ! grep -Fqx "$socket_line" "$profile" 2>/dev/null; then
    printf '%s\n' "$socket_line" >> "$profile"
fi
if ! grep -Fqx "$launch_line" "$profile" 2>/dev/null; then
    printf '%s\n' "$launch_line" >> "$profile"
fi

export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
gpgconf --launch gpg-agent

echo "Alpine uses gpg-agent for YubiKey SSH support at $SSH_AUTH_SOCK"
