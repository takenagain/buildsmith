#!/bin/bash

# Install Node.js using Homebrew
brew install node@lts

# Make sure we're using the Homebrew-installed Node.js
export PATH="/usr/local/opt/node@lts/bin:$PATH"
# For Apple Silicon Macs
if [[ $(uname -m) == 'arm64' ]]; then
  export PATH="/opt/homebrew/opt/node@lts/bin:$PATH"
fi

# Update npm to specific version
npm install -g npm@11.2.0

# Install global npm packages
npm install -g npm-check-updates
