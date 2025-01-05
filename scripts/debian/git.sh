sudo apt install -y libpam-u2f yubikey-agent pinentry-qt pcscd
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock"
echo "export SSH_AUTH_SOCK=\"${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock\"" | tee -a ~/.bashrc

echo "[Unit]
Description=Seamless ssh-agent for YubiKeys
Documentation=https://filippo.io/yubikey-agent

[Service]
ExecStart=/usr/bin/yubikey-agent -l %t/yubikey-agent/yubikey-agent.sock
ExecReload=/bin/kill -HUP $MAINPID
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
WantedBy=default.target" | sudo tee /etc/systemd/system/yubikey-agent.service

systemctl daemon-reload --user
sudo systemctl enable --now pcscd.socket
systemctl --user enable --now yubikey-agent

# Restore the SSH credentials fro the security key
cd ~/.ssh
ssh-keygen -K

# Configure git
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_sk_rk.pub
git config --global commit.gpgsign true
git config --global tag.gpgSign true

echo "IdentityFile ~/.ssh/id_ed25519_sk_rk" >> ~/.ssh/config
