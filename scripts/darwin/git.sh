#!/bin/bash

# Install required packages via Homebrew
brew install yubikey-agent pinentry-mac pcscd libpam-u2f

# Set up Yubikey agent
export SSH_AUTH_SOCK="$HOME/Library/Containers/com.filippo.yubikey-agent/Data/yubikey-agent.sock"
echo "export SSH_AUTH_SOCK=\"$HOME/Library/Containers/com.filippo.yubikey-agent/Data/yubikey-agent.sock\"" | tee -a ~/.zshrc
echo "export SSH_AUTH_SOCK=\"$HOME/Library/Containers/com.filippo.yubikey-agent/Data/yubikey-agent.sock\"" | tee -a ~/.bashrc

# Create LaunchAgent for yubikey-agent
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/io.filippo.yubikey-agent.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.filippo.yubikey-agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/yubikey-agent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load and start the services
launchctl load -w ~/Library/LaunchAgents/io.filippo.yubikey-agent.plist
sudo launchctl load -w /System/Library/LaunchDaemons/org.pcscd.pcscd.plist 2>/dev/null || true

# Restore the SSH credentials from the security key
cd ~/.ssh
ssh-keygen -K

# Configure git
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_sk_rk.pub
git config --global commit.gpgsign true
git config --global tag.gpgSign true

echo "IdentityFile ~/.ssh/id_ed25519_sk_rk" >> ~/.ssh/config
