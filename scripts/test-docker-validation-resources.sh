#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resource_helper="$repository_root/scripts/lib/docker-validation-resources.sh"

if [ ! -f "$resource_helper" ]; then
    echo "Missing Docker validation resource helper: $resource_helper" >&2
    exit 1
fi

assert_array_pair() {
    local expected_key="$1"
    local expected_value="$2"
    local index

    for ((index = 0; index < ${#buildsmith_docker_resource_args[@]} - 1; index++)); do
        if [ "${buildsmith_docker_resource_args[$index]}" = "$expected_key" ] &&
            [ "${buildsmith_docker_resource_args[$((index + 1))]}" = "$expected_value" ]; then
            return 0
        fi
    done

    printf 'Missing Docker argument pair: %s %s\n' "$expected_key" "$expected_value" >&2
    return 1
}

(
    unset BUILDSMITH_DOCKER_MEMORY_LIMIT
    unset BUILDSMITH_DOCKER_MEMORY_SWAP_LIMIT
    unset BUILDSMITH_DOCKER_PIDS_LIMIT
    unset BUILDSMITH_DOCKER_OOM_SCORE_ADJ
    unset BUILDSMITH_BUILD_JOBS
    # shellcheck source=/dev/null
    source "$resource_helper"
    assert_array_pair --memory 12g
    assert_array_pair --memory-swap 16g
    assert_array_pair --pids-limit 2048
    assert_array_pair --oom-score-adj 500
    assert_array_pair --env MAKEFLAGS=-j4
    assert_array_pair --env CARGO_BUILD_JOBS=4
    assert_array_pair --env CMAKE_BUILD_PARALLEL_LEVEL=4
    assert_array_pair --env MAX_JOBS=4
    assert_array_pair --env NVM_MAKE_JOBS=4
)

(
    export BUILDSMITH_DOCKER_MEMORY_LIMIT=10g
    export BUILDSMITH_DOCKER_MEMORY_SWAP_LIMIT=13g
    export BUILDSMITH_DOCKER_PIDS_LIMIT=1024
    export BUILDSMITH_DOCKER_OOM_SCORE_ADJ=750
    export BUILDSMITH_BUILD_JOBS=6
    # shellcheck source=/dev/null
    source "$resource_helper"
    assert_array_pair --memory 10g
    assert_array_pair --memory-swap 13g
    assert_array_pair --pids-limit 1024
    assert_array_pair --oom-score-adj 750
    assert_array_pair --env MAKEFLAGS=-j6
    assert_array_pair --env CARGO_BUILD_JOBS=6
    assert_array_pair --env CMAKE_BUILD_PARALLEL_LEVEL=6
    assert_array_pair --env MAX_JOBS=6
    assert_array_pair --env NVM_MAKE_JOBS=6
)

validation_scripts=(
    scripts/test-install-docker.sh
    scripts/test-scripts-docker.sh
    scripts/test-debian-flutter-android-sdk-docker.sh
    scripts/test-arch-nodejs-docker.sh
    scripts/test-arch-python-docker.sh
    scripts/test-create-appimage-desktop-user-ownership.sh
    scripts/test-alpine-openssh-server-docker.sh
    scripts/test-ubuntu-openssh-server-fallback-docker.sh
)

for relative_script in "${validation_scripts[@]}"; do
    script="$repository_root/$relative_script"
    if ! grep -Fq 'source "$repository_root/scripts/lib/docker-validation-resources.sh"' "$script"; then
        echo "$relative_script does not source the Docker resource helper." >&2
        exit 1
    fi
    if ! grep -Fq '"${buildsmith_docker_resource_args[@]}"' "$script"; then
        echo "$relative_script does not apply the Docker resource arguments." >&2
        exit 1
    fi
done

if ! grep -Fq 'NVM_MAKE_JOBS="$buildsmith_build_jobs"' "$repository_root/scripts/test-scripts-docker.sh"; then
    echo 'scripts/test-scripts-docker.sh does not preserve NVM_MAKE_JOBS for the installer user.' >&2
    exit 1
fi

printf '%s\n' 'Docker validation resource contracts passed.'
