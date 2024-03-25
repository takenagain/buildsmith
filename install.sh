#!/bin/bash

# [ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

timedatectl set-local-rtc 1 --adjust-system-clock
timedatectl

./flatpak.sh
./ssh.sh
./podman_docker.sh
./rocm.sh
./flutter.sh

docker compose -f rocm-compose.yml up -d
docker compose -f rustdesk-compose.yml up -d

./modular.sh