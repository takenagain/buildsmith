/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install neovim
sudo apt-get update
sudo apt-get install -y python-dev python-pip python3-dev python3-pip fd-find

git clone https://github.com/takenagain/nvchad-config.git ~/.config/nvim
