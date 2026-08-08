#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu --needed --noconfirm nodejs npm
npm install --global npm@latest npm-check-updates
