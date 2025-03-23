#!/bin/bash

brew install node@lts

# Make sure we're using the Homebrew-installed Node.js
export PATH="/usr/local/opt/node@lts/bin:$PATH"
# For Apple Silicon Macs
if [[ $(uname -m) == 'arm64' ]]; then
  export PATH="/opt/homebrew/opt/node@lts/bin:$PATH"
fi

npm install -g npm@latest
npm install -g npm-check-updates
