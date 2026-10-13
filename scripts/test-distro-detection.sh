#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repository_root/scripts/lib/distro-detection.sh"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

fail() {
    printf 'Distro detection contract failure: %s\n' "$1" >&2
    exit 1
}

# shellcheck source=scripts/lib/distro-detection.sh
source "$helper"

bootstrap_predicate="$(sed -n '/^is_arch_family() {/,/^}/p' "$repository_root/install.sh")"
[ -n "$bootstrap_predicate" ] || fail 'install.sh must define its self-contained Arch-family predicate'
eval "$bootstrap_predicate"

assert_arch_family() {
    local name="$1"
    local metadata="$2"
    local fixture="$test_root/os-release"
    printf '%s\n' "$metadata" > "$fixture"
    is_arch_family_os_release "$fixture" || fail "$name should be recognized by the shared predicate"
    is_arch_family "$fixture" || fail "$name should be recognized by the streamed bootstrap predicate"
}

assert_not_arch_family() {
    local name="$1"
    local metadata="$2"
    local fixture="$test_root/os-release"
    printf '%s\n' "$metadata" > "$fixture"
    if is_arch_family_os_release "$fixture"; then
        fail "$name should not be recognized by the shared predicate"
    fi
    if is_arch_family "$fixture"; then
        fail "$name should not be recognized by the streamed bootstrap predicate"
    fi
}

assert_arch_family CachyOS $'ID=cachyos\nID_LIKE=arch'
assert_arch_family EndeavourOS $'ID=endeavouros\nID_LIKE=arch'
assert_arch_family Manjaro $'ID=manjaro\nID_LIKE=arch'
assert_arch_family Garuda $'ID=garuda\nID_LIKE=arch'
assert_arch_family Omarchy $'ID=omarchy\nID_LIKE=arch'
assert_arch_family Arch $'ID=arch\nID_LIKE=""'
assert_arch_family QuotedArch $'ID=cachyos\nID_LIKE="arch manjaro"'
assert_not_arch_family Bazzite $'ID=bazzite\nID_LIKE="fedora"'
assert_not_arch_family ArchLinuxSubstring $'ID=custom\nID_LIKE=archlinux'
assert_not_arch_family NotArchSubstring $'ID=custom\nID_LIKE=notarch'

grep -Fq 'ID_LIKE' "$repository_root/install.sh" || \
    fail 'the streamed bootstrap must recognize Arch ID_LIKE metadata before a checkout exists'
grep -Fq 'is_arch_family' "$repository_root/install.sh" || \
    fail 'install.sh must call its self-contained Arch-family predicate'
grep -Fq 'is_arch_family_os_release' "$repository_root/Makefile" || \
    fail 'Makefile must use the shared Arch-family predicate'
grep -Fq 'Bazzite' "$repository_root/README.md" || \
    fail 'README must clarify that Bazzite uses Fedora Atomic rather than pacman/yay'

printf '%s\n' 'Arch-family distro detection contracts passed.'
