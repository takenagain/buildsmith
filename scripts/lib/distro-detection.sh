#!/usr/bin/env bash

is_arch_family_os_release() {
    local os_release_file="${1:-/etc/os-release}"
    [ -r "$os_release_file" ] || return 1

    local ID=''
    local ID_LIKE=''
    # shellcheck disable=SC1090
    . "$os_release_file"

    [ "${ID:-}" = 'arch' ] && return 0

    local -a id_like_tokens=()
    read -r -a id_like_tokens <<< "${ID_LIKE:-}"

    local id_like
    for id_like in "${id_like_tokens[@]}"; do
        [ "$id_like" = 'arch' ] && return 0
    done

    return 1
}
