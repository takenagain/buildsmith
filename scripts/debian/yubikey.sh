#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Run the YubiKey setup as the desktop user, not as root." >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y libpam-u2f openssh-client yubikey-agent pinentry-qt pcscd

agent_path="$(command -v yubikey-agent)"
unit_dir="$HOME/.config/systemd/user"
unit_path="$unit_dir/yubikey-agent.service"
socket_path='${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock'

mkdir -p "$unit_dir"
cat > "$unit_path" <<EOF
[Unit]
Description=Seamless ssh-agent for YubiKeys
Documentation=https://github.com/FiloSottile/yubikey-agent

[Service]
ExecStart=${agent_path} -l %t/yubikey-agent/yubikey-agent.sock
ExecReload=/bin/kill -HUP \$MAINPID
Environment=SSH_AUTH_SOCK=%t/yubikey-agent/yubikey-agent.sock
IPAddressDeny=any
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
SystemCallErrorNumber=EPERM
SystemCallArchitectures=native
NoNewPrivileges=yes
KeyringMode=private
UMask=0177
RuntimeDirectory=yubikey-agent

[Install]
WantedBy=default.target
EOF
chmod 600 "$unit_path"

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    echo "XDG_RUNTIME_DIR is required for the systemd user agent." >&2
    exit 1
fi

profile="$HOME/.profile"
profile_line='export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock"'
if ! grep -Fqx "$profile_line" "$profile" 2>/dev/null; then
    printf '%s\n' "$profile_line" >> "$profile"
fi
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/yubikey-agent/yubikey-agent.sock"

environment_names=(SSH_AUTH_SOCK)
for variable in DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS XAUTHORITY; do
    if [ -n "${!variable:-}" ]; then
        environment_names+=("$variable")
    fi
done

sudo systemctl enable --now pcscd.socket
systemctl --user import-environment "${environment_names[@]}"
systemctl --user daemon-reload
systemctl --user enable --now yubikey-agent.service

if [ "${CI:-0}" != "1" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    (
        cd "$HOME/.ssh"
        ssh-keygen -K
    )
fi

echo "YubiKey ssh-agent is running at $SSH_AUTH_SOCK"
