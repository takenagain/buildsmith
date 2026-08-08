#!/bin/bash

sudo apt install -y python3 python3-pip python3-venv pipx libreadline8 libreadline-dev
pipx ensurepath
pipx install poetry

curl -LsSf https://astral.sh/uv/install.sh | sh
