#!/usr/bin/env bash

# Shared host-safety defaults for Docker-based validation. Callers may
# deliberately override these values in their environment.
buildsmith_docker_memory_limit="${BUILDSMITH_DOCKER_MEMORY_LIMIT:-12g}"
buildsmith_docker_memory_swap_limit="${BUILDSMITH_DOCKER_MEMORY_SWAP_LIMIT:-16g}"
buildsmith_docker_pids_limit="${BUILDSMITH_DOCKER_PIDS_LIMIT:-2048}"
buildsmith_docker_oom_score_adj="${BUILDSMITH_DOCKER_OOM_SCORE_ADJ:-500}"
buildsmith_build_jobs="${BUILDSMITH_BUILD_JOBS:-4}"

if ! [[ "$buildsmith_docker_pids_limit" =~ ^[1-9][0-9]*$ ]]; then
    echo 'BUILDSMITH_DOCKER_PIDS_LIMIT must be a positive integer.' >&2
    return 2
fi

if ! [[ "$buildsmith_build_jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo 'BUILDSMITH_BUILD_JOBS must be a positive integer.' >&2
    return 2
fi

if ! [[ "$buildsmith_docker_oom_score_adj" =~ ^-?[0-9]+$ ]] ||
    [ "$buildsmith_docker_oom_score_adj" -lt -1000 ] ||
    [ "$buildsmith_docker_oom_score_adj" -gt 1000 ]; then
    echo 'BUILDSMITH_DOCKER_OOM_SCORE_ADJ must be between -1000 and 1000.' >&2
    return 2
fi

buildsmith_docker_resource_args=(
    --memory "$buildsmith_docker_memory_limit"
    --memory-swap "$buildsmith_docker_memory_swap_limit"
    --pids-limit "$buildsmith_docker_pids_limit"
    --oom-score-adj "$buildsmith_docker_oom_score_adj"
    --env "MAKEFLAGS=-j${buildsmith_build_jobs}"
    --env "CARGO_BUILD_JOBS=${buildsmith_build_jobs}"
    --env "CMAKE_BUILD_PARALLEL_LEVEL=${buildsmith_build_jobs}"
    --env "MAX_JOBS=${buildsmith_build_jobs}"
    --env "NVM_MAKE_JOBS=${buildsmith_build_jobs}"
)
