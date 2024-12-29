#!/bin/bash

sudo apt update && sudo apt upgrade -y && sudo apt install -y flatpak

sudo apt install -y gnome-software-plugin-flatpak

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
