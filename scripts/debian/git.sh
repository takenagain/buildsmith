sudo apt install libpam-u2f yubikey-agent
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock"
echo "export SSH_AUTH_SOCK=\"${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock\"" | tee -a ~/.bashrc

# Restore the SSH credentials fro the security key
cd ~/.ssh
ssh-keygen -K

# Configure git
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_sk_rk.pub
git config --global commit.gpgsign true
git config --global tag.gpgSign true