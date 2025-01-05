#!/bin/bash

sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo apt install -y python2-setuptools python3-wheel
sudo usermod -a -G render,video $LOGNAME # Add the current user to the render and video groups
wget https://repo.radeon.com/amdgpu-install/5.2.4/ubuntu/noble/amdgpu-install_6.2.60204-1_all.deb
sudo apt install -y ./amdgpu-install_5.2.60204-1_all.deb
sudo apt update
sudo apt install -y rocm
