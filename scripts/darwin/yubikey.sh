#!/usr/bin/env bash

set -euo pipefail

brew install openssh yubikey-agent pinentry-mac
brew install --cask yubico-yubikey-manager

agent_path="$(brew --prefix)/bin/yubikey-agent"
socket_path="$HOME/Library/Containers/com.filippo.yubikey-agent/Data/yubikey-agent.sock"
profile_line="export SSH_AUTH_SOCK=\"$socket_path\""

for profile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if ! grep -Fqx "$profile_line" "$profile" 2>/dev/null; then
        printf '%s\n' "$profile_line" >> "$profile"
    fi
done
export SSH_AUTH_SOCK="$socket_path"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$HOME/Library/LaunchAgents/io.filippo.yubikey-agent.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.filippo.yubikey-agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>${agent_path}</string>
        <string>-l</string>
        <string>${socket_path}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload -w "$HOME/Library/LaunchAgents/io.filippo.yubikey-agent.plist" 2>/dev/null || true
launchctl load -w "$HOME/Library/LaunchAgents/io.filippo.yubikey-agent.plist"

if [ "${CI:-0}" != "1" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    (
        cd "$HOME/.ssh"
        ssh-keygen -K
    )
fi
