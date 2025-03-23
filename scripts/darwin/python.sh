#!/bin/bash

# Install Python and related tools via Homebrew
brew install python python-pip pipx readline

# Setup pipx and poetry
pipx ensurepath
pipx install poetry

# Install pyenv using Homebrew
brew install pyenv

# Add pyenv to shell configuration
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc

# Set up pyenv in current shell
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Install required dependencies for building Python
brew install openssl readline sqlite3 xz zlib tcl-tk

# Install Python versions with pyenv
pyenv install 3.13
pyenv install 3.12
pyenv install 3.11
pyenv global 3.13

# Install modern Python tooling
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -sSf https://rye.astral.sh/get | bash
