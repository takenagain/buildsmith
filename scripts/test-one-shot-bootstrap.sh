#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$repository_root/install.sh"
readme="$repository_root/README.md"
repository_url='https://github.com/takenagain/buildsmith.git'
raw_installer_url='https://raw.githubusercontent.com/takenagain/buildsmith/main/install.sh'

fail() {
    printf 'One-shot bootstrap contract failure: %s\n' "$1" >&2
    exit 1
}

grep -Fq "curl -fsSL $raw_installer_url | bash" "$readme" || \
    fail 'README must document the raw GitHub one-shot command'
grep -Fq "BUILDSMITH_REPOSITORY_URL:-$repository_url" "$installer" || \
    fail 'installer must define the default Buildsmith repository URL'
grep -Fq 'git clone --depth 1' "$installer" || \
    fail 'installer must clone the repository when streamed without a checkout'
grep -Fq 'BUILDSMITH_BOOTSTRAP_DIR' "$installer" || \
    fail 'installer must clean the temporary streamed-install checkout'
grep -Fq 'ca-certificates curl git' "$installer" || \
    fail 'installer bootstrap dependencies must include Git'

printf '%s\n' 'One-shot bootstrap contracts passed.'
