set -e

# Ubuntu updates
sudo apt update && sudo apt upgrade -y && sudo snap refresh
sudo apt install -y flatpak && flatpak update -y
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub io.github.zen_browser.zen
flatpak install -y com.mattjakeman.ExtensionManager
sudo apt install -y radeontop htop curl git htop python3 python3-pip python3-venv screen tmux neovim gcc g++ cmake clang llvm
sudo snap install obsidian --classic
sudo snap install bitwarden
sudo snap install vlc
sudo snap install codium --classic
sudo snap install go --classic
sudo snap install remmina
sudo snap install brave
sudo snap install keybase
sudo snap install telegram-desktop

# GitHub Desktop
wget -qO - https://apt.packages.shiftkey.dev/gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/shiftkey-packages.gpg > /dev/null
sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/shiftkey-packages.gpg] https://apt.packages.shiftkey.dev/ubuntu/ any main" > /etc/apt/sources.list.d/shiftkey-packages.list'

## Install Github Desktop for Ubuntu
sudo apt update && sudo apt install github-desktop

# Docker
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
wget https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb
sudo apt-get update
sudo apt-get install -y ./docker-desktop-amd64.deb
systemctl --user enable docker-desktop
systemctl --user start docker-desktop

# ROCM
sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo apt install python3-setuptools python3-wheel
sudo usermod -a -G render,video $LOGNAME # Add the current user to the render and video groups
wget https://repo.radeon.com/amdgpu-install/6.2.4/ubuntu/noble/amdgpu-install_6.2.60204-1_all.deb
sudo apt install -y ./amdgpu-install_6.2.60204-1_all.deb
sudo apt update
sudo apt install -y amdgpu-dkms rocm

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Toshy (macos keyboard shortcuts)
git clone https://github.com/RedBearAK/toshy.git
cd toshy
./setup_toshy.py install

# ProtonVPN
wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.6_all.deb
sudo dpkg -i ./protonvpn-stable-release_1.0.6_all.deb && sudo apt update
echo "e5e03976d0980bafdf07da2f71b14fbc883c091e72b16772199742c98473002f protonvpn-stable-release_1.0.6_all.deb" | sha256sum --check -
sudo apt -y install proton-vpn-gnome-desktop