#!/bin/sh

# Install required packages
apk add git openssh-client pcsc-lite ccid yubikey-manager 

# Set up Yubikey environment
apk add eudev
rc-update add udev
rc-update add pcscd
rc-service pcscd start

# There's no direct equivalent to yubikey-agent in Alpine repositories
# You can use gpg-agent instead
apk add gnupg pinentry

# Configure GPG agent for SSH
mkdir -p ~/.gnupg
echo "enable-ssh-support" > ~/.gnupg/gpg-agent.conf
echo "pinentry-program /usr/bin/pinentry" >> ~/.gnupg/gpg-agent.conf

# Add GPG agent to shell startup
echo 'export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"' >> ~/.profile
echo 'gpgconf --launch gpg-agent' >> ~/.profile

# Source it for the current session
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
gpgconf --launch gpg-agent

# Set up SSH directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Note: Direct equivalent of ssh-keygen -K might not work the same
echo "To generate SSH keys for your Yubikey, you may need to use:"
echo "ssh-keygen -t ed25519-sk"

# Configure git
git config --global gpg.format ssh
echo "After generating your key, set it with:"
echo "git config --global user.signingkey PATH_TO_YOUR_KEY.pub"
git config --global commit.gpgsign true
git config --global tag.gpgSign true

echo "Add your key to SSH config with:"
echo "echo \"IdentityFile ~/.ssh/YOUR_KEY_NAME\" >> ~/.ssh/config"
