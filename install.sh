#!/bin/bash

USE_CASE=$1

./scripts/flatpak.sh
./scripts/ssh.sh

if [[ "$USE_CASE" == *flutter* ]]; then
    ./scripts/flutter.sh
fi

if [[ "$USE_CASE" == *dual-boot* ]]; then
    timedatectl set-local-rtc 1 --adjust-system-clock
    timedatectl
fi 

if [[ "$USE_CASE" == *docker* ]]; then
    ./scripts/podman_docker.sh
fi 

if [[ "$USE_CASE" == *rocm* ]]; then
    ./scripts/rocm.sh
    if [[ "$USE_CASE" == *docker* ]]; then
        docker compose -f rocm-compose.yml up -d
    fi
fi 

if [[ "$USE_CASE" == *mojo* ]]; then
    ./scripts/modular.sh
fi