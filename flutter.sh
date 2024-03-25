#!/bin/bash

sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
	clang cmake git \
      python3 python3-pip python3-venv \
      ninja-build pkg-config \
      libgtk-3-dev liblzma-dev \
      libstdc++-12-dev \
      libc6:i386 libncurses5:i386 \
    libstdc++6:i386 lib32z1 \
    libbz2-1.0:i386 
    
curl -fsSL https://fvm.app/install.sh | bash

fvm install 3.16.9
fvm install stable
fvm install 2.8.1

echo "export PATH=\"/home/frannas/.fvm_flutter/bin:$PATH\"" >> ~/.bashrc
echo "alias flutter=\"fvm flutter\"" >> ~/.bashrc

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

source ~/.bashrc
nvm install --lts
nvm use --lts

