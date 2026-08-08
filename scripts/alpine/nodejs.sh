#!/bin/sh

set -eu

apk add --no-cache bash curl

# Install the current nvm release.
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash

# Configure nvm in current session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Install the latest available Node.js release.
nvm install node
nvm use node
npm install -g npm@latest
npm install -g npm-check-updates
