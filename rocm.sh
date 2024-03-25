#!/bin/bash

apt update
wget https://repo.radeon.com/amdgpu-install/6.0.2/ubuntu/jammy/amdgpu-install_6.0.60002-1_all.deb
apt install -y ./amdgpu-install_6.0.60002-1_all.deb
amdgpu-install --usecase=graphics,rocm,opencl,openclsdk,mllib,mlsdk
