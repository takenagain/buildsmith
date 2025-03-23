#!/bin/sh

# Install Python and dependencies
apk add python3 py3-pip readline-dev
apk add build-base libffi-dev openssl-dev bzip2-dev zlib-dev xz-dev readline-dev sqlite-dev tk-dev

# Install pipx
pip3 install --user pipx
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
pipx ensurepath
pipx install poetry

# Install pyenv
apk add git
curl https://pyenv.run | bash

# Add pyenv to profile
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile
echo 'eval "$(pyenv init - sh)"' >> ~/.profile

# Set up pyenv in current session
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - sh)"

# Install Python versions
pyenv install 3.13
pyenv install 3.12
pyenv install 3.11
pyenv global 3.13

# Install uv and rye
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -sSf https://rye.astral.sh/get | bash
