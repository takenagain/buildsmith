#!/bin/bash

set -euo pipefail

# Install the current Python and related tools via Homebrew.
brew install python pipx readline

# Set up current Python tooling.
pipx ensurepath
pipx install poetry
curl -LsSf https://astral.sh/uv/install.sh | sh
