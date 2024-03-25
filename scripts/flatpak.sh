#!/bin/bash

apt update && apt upgrade -y && apt install -y flatpak

apt install -y gnome-software-plugin-flatpak

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
