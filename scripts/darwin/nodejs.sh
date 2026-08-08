#!/bin/bash

set -euo pipefail

brew install node

# Make sure we're using the current Homebrew-installed Node.js.
export PATH="$(brew --prefix node)/bin:$PATH"

npm install -g npm@latest
npm install -g npm-check-updates
