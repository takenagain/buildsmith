#!/bin/bash

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

timedatectl set-local-rtc 1 --adjust-system-clock
timedatectl

./flatpak.sh
./podman_docker.sh
./rocm.sh
./flutter.sh
