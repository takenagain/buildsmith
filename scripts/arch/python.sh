#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm python python-pip python-pipx python-poetry pyenv uv
pipx ensurepath
