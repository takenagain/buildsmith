#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"

trap 'rm -rf -- "$test_root"' EXIT

fail() {
    printf 'installer contract failure: %s\n' "$1" >&2
    exit 1
}

assert_act_retries_complete_installer_pipeline() {
    local contract_root="$test_root/act-pipeline-retry"
    local output=''
    local pipeline_attempts='0'

    mkdir -p "$contract_root/bin" "$contract_root/tmp"

    cat > "$contract_root/bin/curl" <<'FAKE_CURL'
#!/bin/sh

set -eu

url=''
output=''
proto=''
saw_tls_v1_2=0
saw_silent=0
saw_show_error=0
saw_fail=0

increment_counter() {
    counter_file="$1"
    counter_value=0

    if [ -s "$counter_file" ]; then
        counter_value="$(cat "$counter_file")"
    fi

    counter_value=$((counter_value + 1))
    printf '%s\n' "$counter_value" > "$counter_file"
    printf '%s\n' "$counter_value"
}

emit_upstream_installer() {
    cat <<'FAKE_INSTALLER'
#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ] || [ "$1" != '-b' ] || [ "$2" != '/usr/local/bin' ]; then
    printf 'unexpected act installer arguments: %s\n' "$*" >&2
    exit 64
fi

printf '%s\n' "$*" >> "${ACT_INSTALLER_ARGUMENTS:?}"

curl --fail --location \
    --output "${ACT_RELEASE_ASSET:?}" \
    'https://github.com/nektos/act/releases/download/v-test/act_Linux_x86_64.tar.gz'

printf '%s\n' 'installed' > "${ACT_INSTALL_SUCCESS:?}"
FAKE_INSTALLER
}

while [ "$#" -gt 0 ]; do
    argument="$1"
    case "$argument" in
        --proto)
            shift
            [ "$#" -gt 0 ] || exit 64
            proto="$1"
            ;;
        --tlsv1.2)
            saw_tls_v1_2=1
            ;;
        --output|-o)
            shift
            [ "$#" -gt 0 ] || exit 64
            output="$1"
            ;;
        --output=*)
            output="${argument#--output=}"
            ;;
        -o*)
            output="${argument#-o}"
            ;;
        --fail)
            saw_fail=1
            ;;
        --show-error)
            saw_show_error=1
            ;;
        --silent)
            saw_silent=1
            ;;
        --location)
            ;;
        -*)
            case "$argument" in
                *f*) saw_fail=1 ;;
            esac
            case "$argument" in
                *S*) saw_show_error=1 ;;
            esac
            case "$argument" in
                *s*) saw_silent=1 ;;
            esac
            ;;
        http://*|https://*)
            url="$argument"
            ;;
    esac
    shift
done

case "$url" in
    'https://raw.githubusercontent.com/nektos/act/master/install.sh')
        if [ "$proto" != '=https' ] || \
            [ "$saw_tls_v1_2" -ne 1 ] || \
            [ "$saw_silent" -ne 1 ] || \
            [ "$saw_show_error" -ne 1 ] || \
            [ "$saw_fail" -ne 1 ]; then
            printf '%s\n' 'act installer download lost its HTTPS/TLS curl hardening' >&2
            exit 64
        fi

        increment_counter "${ACT_PIPELINE_ATTEMPTS:?}" >/dev/null
        if [ -n "$output" ] && [ "$output" != '-' ]; then
            emit_upstream_installer > "$output"
        else
            emit_upstream_installer
        fi
        ;;
    'https://github.com/nektos/act/releases/download/v-test/act_Linux_x86_64.tar.gz')
        asset_attempt="$(increment_counter "${ACT_RELEASE_ATTEMPTS:?}")"
        if [ "$asset_attempt" -eq 1 ]; then
            printf '%s\n' 'curl: (22) The requested URL returned error: 504' >&2
            exit 22
        fi

        if [ -n "$output" ] && [ "$output" != '-' ]; then
            printf '%s\n' 'fake act release asset' > "$output"
        else
            printf '%s\n' 'fake act release asset'
        fi
        ;;
    *)
        printf 'unexpected curl URL: %s\n' "${url:-none}" >&2
        exit 64
        ;;
esac
FAKE_CURL

    cat > "$contract_root/bin/sudo" <<'FAKE_SUDO'
#!/bin/sh

set -eu

printf '%s\n' "$*" >> "${ACT_SUDO_INVOCATIONS:?}"

if [ "${1-}" != 'bash' ]; then
    printf 'unexpected sudo command: %s\n' "$*" >&2
    exit 64
fi

exec "$@"
FAKE_SUDO

    cat > "$contract_root/bin/sleep" <<'FAKE_SLEEP'
#!/bin/sh

set -eu

printf '%s\n' "${1-}" >> "${ACT_RETRY_DELAYS:?}"
FAKE_SLEEP

    chmod +x "$contract_root/bin/curl" "$contract_root/bin/sleep" "$contract_root/bin/sudo"

    if output="$(
        env \
            PATH="$contract_root/bin:/usr/bin:/bin" \
            TMPDIR="$contract_root/tmp" \
            ACT_INSTALLER_ARGUMENTS="$contract_root/installer-arguments" \
            ACT_INSTALL_SUCCESS="$contract_root/install-success" \
            ACT_PIPELINE_ATTEMPTS="$contract_root/pipeline-attempts" \
            ACT_RELEASE_ASSET="$contract_root/act-release-asset" \
            ACT_RELEASE_ATTEMPTS="$contract_root/release-attempts" \
            ACT_RETRY_DELAYS="$contract_root/retry-delays" \
            ACT_SUDO_INVOCATIONS="$contract_root/sudo-invocations" \
            sh "$repository_root/scripts/unix/act.sh" 2>&1
    )"; then
        :
    else
        if [ -s "$contract_root/pipeline-attempts" ]; then
            pipeline_attempts="$(cat "$contract_root/pipeline-attempts")"
        fi
        fail "act installer must recover from one internal HTTP 504; stopped after $pipeline_attempts full-pipeline attempt(s): $output"
    fi

    if [ ! -s "$contract_root/pipeline-attempts" ] || \
        [ "$(cat "$contract_root/pipeline-attempts")" != '2' ]; then
        fail 'act installer must fetch and run the complete upstream pipeline exactly twice'
    fi

    if [ ! -s "$contract_root/release-attempts" ] || \
        [ "$(cat "$contract_root/release-attempts")" != '2' ]; then
        fail 'act upstream installer must attempt its release-asset download exactly twice'
    fi

    if [ "$(wc -l < "$contract_root/sudo-invocations" | tr -d '[:space:]')" != '2' ] || \
        grep -Fvx -- 'bash -s -- -b /usr/local/bin' "$contract_root/sudo-invocations" >/dev/null; then
        fail 'act installer must execute both full-pipeline attempts with the original sudo bash arguments'
    fi

    if [ "$(wc -l < "$contract_root/installer-arguments" | tr -d '[:space:]')" != '2' ] || \
        grep -Fvx -- '-b /usr/local/bin' "$contract_root/installer-arguments" >/dev/null; then
        fail 'both upstream installer attempts must receive -b /usr/local/bin'
    fi

    if [ ! -s "$contract_root/install-success" ] || \
        [ "$(cat "$contract_root/install-success")" != 'installed' ]; then
        fail 'act installer did not complete after the transient internal HTTP 504'
    fi
}

assert_alpine_base_packages_exclude_bitwarden_runtime() {
    local contract_root="$test_root/alpine-base-packages"
    local output=''

    mkdir -p "$contract_root/bin" "$contract_root/home" "$contract_root/tmp"

    cat > "$contract_root/bin/sudo" <<'FAKE_SUDO'
#!/bin/sh

set -eu

if [ "$#" -lt 2 ] || [ "$1" != 'apk' ]; then
    printf 'unexpected sudo invocation: %s\n' "$*" >&2
    exit 64
fi

printf '%s\n' "$*" >> "${APK_INVOCATIONS:?}"
FAKE_SUDO

    for command in curl node npm sha512sum; do
        cat > "$contract_root/bin/$command" <<'POISON_RUNTIME'
#!/bin/sh

printf 'Alpine base package installer must not invoke %s\n' "$(basename "$0")" >&2
exit 97
POISON_RUNTIME
    done

    chmod +x "$contract_root/bin/"*

    if ! output="$(
        env \
            HOME="$contract_root/home" \
            PATH="$contract_root/bin:/usr/bin:/bin" \
            TMPDIR="$contract_root/tmp" \
            APK_INVOCATIONS="$contract_root/apk-invocations" \
            sh "$repository_root/scripts/alpine/apk.sh" 2>&1
    )"; then
        fail "Alpine base package setup must leave Bitwarden to the supported Node installer: $output"
    fi

    if grep -Eq '(^| )(nodejs|npm)( |$)' "$contract_root/apk-invocations"; then
        fail 'Alpine base packages must not install the moving distro Node.js/npm runtime'
    fi
}

assert_alpine_bitwarden_supported_runtime_contract() {
    local contract_root="$test_root/alpine-bitwarden-supported-runtime"
    local expected_nvm_invocations=$'install -s 24.21.0\nuse 24.21.0\ninstall -s node\nuse node'
    local expected_sha512='46c9a7b0999d11ccf256c7f9dfb5bc8fc1a5cdb8afad20bd0361dc4b0be28f76e7d15cf8a6c09c2428a3d7d8c9450c60ff85aeec6b9d0b8538e65d939dbdbe18'
    local expected_url='https://registry.npmjs.org/@bitwarden/cli/-/cli-2026.9.1.tgz'
    local install_root="$contract_root/home/.local/share/buildsmith/bitwarden-cli"
    local latest_bin="$contract_root/home/.nvm/versions/node/v26.7.0/bin"
    local output=''
    local supported_bin="$contract_root/home/.nvm/versions/node/v24.21.0/bin"

    mkdir -p \
        "$contract_root/bin" \
        "$contract_root/home" \
        "$contract_root/tmp" \
        "$latest_bin" \
        "$supported_bin"

    cat > "$contract_root/bin/sudo" <<'FAKE_SUDO'
#!/bin/sh

set -eu

if [ "$#" -lt 3 ] || [ "$1" != 'apk' ] || [ "$2" != 'add' ] || [ "$3" != '--no-cache' ]; then
    printf 'unexpected sudo invocation: %s\n' "$*" >&2
    exit 64
fi
FAKE_SUDO

    cat > "$contract_root/bin/curl" <<'FAKE_CURL'
#!/bin/sh

set -eu

output=''
proto=''
retry_count=''
saw_fail=0
saw_location=0
saw_show_error=0
saw_tls_v1_2=0
url=''

while [ "$#" -gt 0 ]; do
    argument="$1"
    case "$argument" in
        --proto)
            shift
            proto="${1-}"
            ;;
        --tlsv1.2)
            saw_tls_v1_2=1
            ;;
        --fail)
            saw_fail=1
            ;;
        --show-error)
            saw_show_error=1
            ;;
        --location)
            saw_location=1
            ;;
        --retry)
            shift
            retry_count="${1-}"
            ;;
        --output)
            shift
            output="${1-}"
            ;;
        http://*|https://*)
            url="$argument"
            ;;
        *)
            printf 'unexpected curl argument: %s\n' "$argument" >&2
            exit 64
            ;;
    esac
    shift
done

if [ -z "$output" ] || [ "$saw_fail" -ne 1 ] || [ "$saw_show_error" -ne 1 ] || \
    [ "$saw_location" -ne 1 ] || [ "$retry_count" != '3' ]; then
    printf 'curl call is missing required output/fail/show-error/location/retry behavior: %s\n' "$url" >&2
    exit 64
fi

case "$url" in
    'https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh')
        printf '%s\n' "$url" > "${NVM_CURL_URL_EVIDENCE:?}"
        cat > "$output" <<'FAKE_INSTALLER'
#!/usr/bin/env bash

set -euo pipefail

mkdir -p "$HOME/.nvm"
cat > "$HOME/.nvm/nvm.sh" <<'FAKE_NVM'
nvm() {
    printf '%s\n' "$*" >> "${NVM_INVOCATIONS:?}"

    if [ "${1-}" = 'use' ]; then
        case "${2-}" in
            24.21.0)
                export PATH="$HOME/.nvm/versions/node/v24.21.0/bin:$PATH"
                ;;
            node)
                export PATH="$HOME/.nvm/versions/node/v26.7.0/bin:$PATH"
                ;;
            *)
                printf 'unexpected nvm use target: %s\n' "${2-}" >&2
                return 64
                ;;
        esac
    fi
}
FAKE_NVM
FAKE_INSTALLER
        ;;
    'https://registry.npmjs.org/@bitwarden/cli/-/cli-2026.9.1.tgz')
        if [ "$proto" != '=https' ] || [ "$saw_tls_v1_2" -ne 1 ]; then
            printf '%s\n' 'Bitwarden archive download lost HTTPS/TLS hardening' >&2
            exit 64
        fi
        printf '%s\n' "$url" > "${BITWARDEN_CURL_URL_EVIDENCE:?}"
        printf '%s\n' 'offline Bitwarden archive fixture' > "$output"
        ;;
    *)
        printf 'unexpected curl URL: %s\n' "${url:-none}" >&2
        exit 64
        ;;
esac
FAKE_CURL

    cat > "$contract_root/bin/sha512sum" <<'FAKE_SHA512SUM'
#!/bin/sh

set -eu

if [ "$#" -ne 2 ] || [ "$1" != '-c' ] || [ "$2" != '-' ]; then
    printf 'unexpected sha512sum invocation: %s\n' "$*" >&2
    exit 64
fi

checksum_input="$(cat)"
printf '%s\n' "$checksum_input" > "${BITWARDEN_SHA512_EVIDENCE:?}"
set -- $checksum_input

if [ "$#" -ne 2 ] || [ "$1" != "${BITWARDEN_EXPECTED_SHA512:?}" ] || \
    [ "$2" != "${BITWARDEN_EXPECTED_ARCHIVE:?}" ] || [ ! -f "$2" ]; then
    printf 'unexpected Bitwarden checksum input: %s\n' "$checksum_input" >&2
    exit 64
fi

printf '%s: OK\n' "$2"
FAKE_SHA512SUM

    cat > "$supported_bin/node" <<'SUPPORTED_NODE'
#!/bin/sh

set -eu

if [ "$#" -eq 1 ] && [ "$1" = '--version' ]; then
    printf '%s\n' 'v24.21.0'
    exit 0
fi

if [ "${1-}" = "${BITWARDEN_EXPECTED_ENTRY:?}" ]; then
    printf '%s\n' "$*" >> "${BITWARDEN_NODE_INVOCATIONS:?}"
    if [ "$#" -eq 2 ] && [ "$2" = '--version' ]; then
        printf '%s\n' '2026.9.1'
        exit 0
    fi
fi

printf 'unexpected supported Node invocation: %s\n' "$*" >&2
exit 64
SUPPORTED_NODE

    cat > "$supported_bin/npm" <<'SUPPORTED_NPM'
#!/bin/sh

set -eu

if [ "$#" -eq 1 ] && [ "$1" = '--version' ]; then
    printf '%s\n' '11.19.0'
    exit 0
fi

if [ "${1-}" != 'ci' ]; then
    printf 'unexpected supported npm invocation: %s\n' "$*" >&2
    exit 64
fi

if [ "$PWD" != "${BITWARDEN_INSTALL_ROOT:?}" ] || \
    [ "$(command -v node)" != "${BITWARDEN_SUPPORTED_NODE:?}" ] || \
    [ ! -s package.json ] || [ ! -s package-lock.json ] || [ ! -s bitwarden-cli.tgz ]; then
    printf '%s\n' 'supported npm did not receive the isolated locked install inputs' >&2
    exit 64
fi

printf '%s\n' "$*" > "${BITWARDEN_NPM_CI_EVIDENCE:?}"
mkdir -p node_modules/@bitwarden/cli/build
printf '%s\n' 'offline Bitwarden entry fixture' > node_modules/@bitwarden/cli/build/bw.js
SUPPORTED_NPM

    cat > "$latest_bin/node" <<'LATEST_NODE'
#!/bin/sh

if [ "$#" -eq 1 ] && [ "$1" = '--version' ]; then
    printf '%s\n' 'v26.7.0'
    exit 0
fi

printf 'unexpected latest Node invocation: %s\n' "$*" >&2
exit 64
LATEST_NODE

    cat > "$latest_bin/npm" <<'LATEST_NPM'
#!/bin/sh

set -eu

printf '%s\n' "$*" >> "${LATEST_NPM_INVOCATIONS:?}"
case "$*" in
    'install -g npm@latest'|'install -g npm-check-updates')
        exit 0
        ;;
    *)
        printf 'unexpected latest npm invocation: %s\n' "$*" >&2
        exit 64
        ;;
esac
LATEST_NPM

    for command in node npm; do
        cat > "$contract_root/bin/$command" <<'POISON_RUNTIME'
#!/bin/sh

printf 'installer used unsupported PATH runtime: %s\n' "$(basename "$0")" >&2
exit 98
POISON_RUNTIME
    done

    chmod +x \
        "$contract_root/bin/"* \
        "$latest_bin/node" \
        "$latest_bin/npm" \
        "$supported_bin/node" \
        "$supported_bin/npm"

    if ! output="$(
        env \
            HOME="$contract_root/home" \
            PATH="$contract_root/bin:/usr/bin:/bin" \
            TMPDIR="$contract_root/tmp" \
            BITWARDEN_CURL_URL_EVIDENCE="$contract_root/bitwarden-curl-url-evidence" \
            BITWARDEN_EXPECTED_ARCHIVE="$install_root/bitwarden-cli.tgz" \
            BITWARDEN_EXPECTED_ENTRY="$install_root/node_modules/@bitwarden/cli/build/bw.js" \
            BITWARDEN_EXPECTED_SHA512="$expected_sha512" \
            BITWARDEN_INSTALL_ROOT="$install_root" \
            BITWARDEN_NODE_INVOCATIONS="$contract_root/bitwarden-node-invocations" \
            BITWARDEN_NPM_CI_EVIDENCE="$contract_root/bitwarden-npm-ci-evidence" \
            BITWARDEN_SHA512_EVIDENCE="$contract_root/bitwarden-sha512-evidence" \
            BITWARDEN_SUPPORTED_NODE="$supported_bin/node" \
            LATEST_NPM_INVOCATIONS="$contract_root/latest-npm-invocations" \
            NVM_CURL_URL_EVIDENCE="$contract_root/nvm-curl-url-evidence" \
            NVM_INVOCATIONS="$contract_root/nvm-invocations" \
            sh "$repository_root/scripts/alpine/nodejs.sh" 2>&1
    )"; then
        fail "Alpine Bitwarden supported-runtime install contract failed: $output"
    fi

    if [ "$(cat "$contract_root/nvm-invocations" 2>/dev/null || :)" != "$expected_nvm_invocations" ]; then
        fail 'Alpine Node.js must install/use v24.21.0 for Bitwarden before installing/using latest developer Node'
    fi

    if [ "$(cat "$contract_root/bitwarden-curl-url-evidence" 2>/dev/null || :)" != "$expected_url" ]; then
        fail "Bitwarden must download the official 2026.9.1 archive from $expected_url"
    fi

    if [ "$(awk '{ print $1 }' "$contract_root/bitwarden-sha512-evidence" 2>/dev/null || :)" != "$expected_sha512" ]; then
        fail "Bitwarden archive must be verified with the official SHA-512 $expected_sha512"
    fi

    if [ "$(cat "$contract_root/bitwarden-npm-ci-evidence" 2>/dev/null || :)" != 'ci --ignore-scripts --omit=dev --loglevel=error' ]; then
        fail 'Bitwarden dependencies must be installed with isolated npm ci and no lifecycle scripts'
    fi

    if [ "$(cat "$contract_root/bitwarden-node-invocations" 2>/dev/null || :)" != "$install_root/node_modules/@bitwarden/cli/build/bw.js --version" ]; then
        fail 'the bw wrapper must directly invoke the locked CLI entry with Node v24.21.0'
    fi

    if [ "$(cat "$contract_root/latest-npm-invocations" 2>/dev/null || :)" != $'install -g npm@latest\ninstall -g npm-check-updates' ]; then
        fail 'latest developer Node must remain active for the normal global npm tools'
    fi

    if [ ! -x "$contract_root/home/.local/bin/bw" ]; then
        fail 'the supported-runtime bw wrapper was not installed in the user local bin'
    fi

    if ! cmp -s "$repository_root/scripts/alpine/bitwarden-cli/package.json" "$install_root/package.json" || \
        ! cmp -s "$repository_root/scripts/alpine/bitwarden-cli/package-lock.json" "$install_root/package-lock.json"; then
        fail 'the isolated install must use the committed Bitwarden manifest and lock unchanged'
    fi
}

assert_alpine_bitwarden_lock_integrity_contract() {
    local lock="$repository_root/scripts/alpine/bitwarden-cli/package-lock.json"
    local manifest="$repository_root/scripts/alpine/bitwarden-cli/package.json"
    local expected_integrity='sha512-RsmnsJmdEczyVsf537W8j8GlzbivrSC9A2HcSwvij3bn0Vz4psCcJCij19jJRQxg/4Wu7GudC4U45l2Tnb2+GA=='
    local integrity_count
    local resolved_count

    grep -Fq '"version": "2026.9.1"' "$manifest" || fail 'Bitwarden runtime manifest must target CLI 2026.9.1'
    grep -Fq '"node": "~24"' "$manifest" || fail 'Bitwarden runtime manifest must use the supported Node 24 line'
    grep -Fq '"npm": "~11"' "$manifest" || fail 'Bitwarden runtime manifest must use the supported npm 11 line'
    grep -Fq '"packageManager": "npm@11.19.0"' "$manifest" || fail 'Bitwarden runtime manifest must pin npm 11.19.0'
    grep -Fq '"version": "2026.9.1"' "$lock" || fail 'Bitwarden lock must target CLI 2026.9.1'

    resolved_count="$(awk '/"resolved":/ { count += 1 } END { print count + 0 }' "$lock")"
    integrity_count="$(awk '/"integrity":/ { count += 1 } END { print count + 0 }' "$lock")"

    if [ "$resolved_count" -eq 0 ] || [ "$integrity_count" -ne "$resolved_count" ]; then
        fail "every Bitwarden lock artifact must carry integrity metadata; observed $resolved_count resolutions and $integrity_count integrities"
    fi

    if ! grep -Fq -- "\"integrity\": \"$expected_integrity\"" "$lock"; then
        fail 'the locked local Bitwarden tarball integrity must match the official SHA-512'
    fi
}

assert_alpine_nodejs_source_build_contract() {
    local contract_root="$test_root/alpine-nodejs"
    local direct_root="$contract_root/direct-sh"
    local bash_root="$contract_root/bash"
    local failure_root="$contract_root/curl-failure"
    local output=''
    local curl_output=''
    local -a failures=()
    local -a required_packages=(
        curl
        bash
        ca-certificates
        openssl
        ncurses
        coreutils
        python3
        make
        gcc
        g++
        libgcc
        linux-headers
        grep
        util-linux
        binutils
        findutils
    )
    local package

    mkdir -p \
        "$contract_root/bin" \
        "$direct_root/home" \
        "$bash_root/home" \
        "$failure_root/home/.nvm" \
        "$failure_root/tmp"

    cat > "$contract_root/bin/apk" <<'EOF'
#!/bin/sh

printf '%s\n' 'apk must be invoked through sudo' >&2
exit 99
EOF

    cat > "$contract_root/bin/sudo" <<'EOF'
#!/bin/sh

printf '%s\n' "$@" > "${SUDO_INVOCATION:?}"
exit 0
EOF

    cat > "$contract_root/bin/curl" <<'FAKE_CURL'
#!/bin/sh

set -eu

bitwarden_url='https://registry.npmjs.org/@bitwarden/cli/-/cli-2026.9.1.tgz'
nvm_url='https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh'
output=''
retry_count=''
retry_valid=0
saw_fail=0
saw_location=0
saw_show_error=0
url=''
url_count=0

while [ "$#" -gt 0 ]; do
    argument="$1"
    case "$argument" in
        --proto)
            shift
            ;;
        --tlsv1.2)
            ;;
        --fail)
            saw_fail=1
            ;;
        --show-error)
            saw_show_error=1
            ;;
        --location)
            saw_location=1
            ;;
        --retry)
            shift
            retry_count="${1-}"
            ;;
        --retry=*)
            retry_count="${argument#--retry=}"
            ;;
        --output)
            shift
            output="${1-}"
            ;;
        --output=*)
            output="${argument#--output=}"
            ;;
        -o)
            shift
            output="${1-}"
            ;;
        -o*)
            output="${argument#-o}"
            ;;
        -*)
            case "$argument" in
                *f*) saw_fail=1 ;;
            esac
            case "$argument" in
                *S*) saw_show_error=1 ;;
            esac
            case "$argument" in
                *L*) saw_location=1 ;;
            esac
            ;;
        http://*|https://*)
            url="$argument"
            url_count=$((url_count + 1))
            ;;
    esac
    shift
done

if [ "$url_count" -ne 1 ]; then
    printf 'curl double expected exactly one URL, received %s\n' "${url:-no URL}" >&2
    exit 64
fi

emit_installer() {
    cat <<'FAKE_INSTALLER'
#!/usr/bin/env bash

set -euo pipefail

mkdir -p "$HOME/.nvm"

cat > "$HOME/.nvm/nvm.sh" <<'FAKE_NVM'
nvm() {
    printf '%s\n' "$*" >> "${NVM_INVOCATIONS:?}"
    if [ "${1-}" = 'install' ]; then
        printf '%s\n' "${TMPDIR-unset}" > "${TMPDIR_VALUE:?}"
    fi

    if [ "${1-}" = 'use' ]; then
        case "${2-}" in
            24.21.0)
                export PATH="$HOME/.nvm/versions/node/v24.21.0/bin:$PATH"
                ;;
            node)
                export PATH="$HOME/.nvm/versions/node/v26.7.0/bin:$PATH"
                ;;
            *)
                return 64
                ;;
        esac
    fi
    return 0
}
FAKE_NVM

mkdir -p \
    "$HOME/.nvm/versions/node/v24.21.0/bin" \
    "$HOME/.nvm/versions/node/v26.7.0/bin"

cat > "$HOME/.nvm/versions/node/v24.21.0/bin/node" <<'FAKE_SUPPORTED_NODE'
#!/bin/sh

if [ "$#" -eq 1 ] && [ "$1" = '--version' ]; then
    printf '%s\n' 'v24.21.0'
    exit 0
fi

if [ "${1-}" = "$HOME/.local/share/buildsmith/bitwarden-cli/node_modules/@bitwarden/cli/build/bw.js" ] && \
    [ "${2-}" = '--version' ]; then
    printf '%s\n' '2026.9.1'
    exit 0
fi

exit 64
FAKE_SUPPORTED_NODE

cat > "$HOME/.nvm/versions/node/v24.21.0/bin/npm" <<'FAKE_SUPPORTED_NPM'
#!/bin/sh

set -eu

if [ "$#" -eq 1 ] && [ "$1" = '--version' ]; then
    printf '%s\n' '11.19.0'
    exit 0
fi

if [ "${1-}" = 'ci' ]; then
    mkdir -p node_modules/@bitwarden/cli/build
    printf '%s\n' 'offline Bitwarden entry fixture' > node_modules/@bitwarden/cli/build/bw.js
    exit 0
fi

exit 64
FAKE_SUPPORTED_NPM

cat > "$HOME/.nvm/versions/node/v26.7.0/bin/node" <<'FAKE_LATEST_NODE'
#!/bin/sh

if [ "$#" -eq 1 ] && [ "$1" = '--version' ]; then
    printf '%s\n' 'v26.7.0'
    exit 0
fi

exit 64
FAKE_LATEST_NODE

cat > "$HOME/.nvm/versions/node/v26.7.0/bin/npm" <<'FAKE_LATEST_NPM'
#!/bin/sh

case "$*" in
    'install -g npm@latest'|'install -g npm-check-updates')
        exit 0
        ;;
esac

exit 64
FAKE_LATEST_NPM

cat > "$HOME/.nvm/bash_completion" <<'FAKE_COMPLETION'
nvm_completion_versions=(v0.40.8)
printf '%s|%s\n' "${nvm_completion_versions[0]}" "${BASH_VERSION:?}" > "${BASH_COMPLETION_EVIDENCE:?}"
FAKE_COMPLETION

chmod +x \
    "$HOME/.nvm/nvm.sh" \
    "$HOME/.nvm/versions/node/v24.21.0/bin/node" \
    "$HOME/.nvm/versions/node/v24.21.0/bin/npm" \
    "$HOME/.nvm/versions/node/v26.7.0/bin/node" \
    "$HOME/.nvm/versions/node/v26.7.0/bin/npm"
printf '%s\n' 'v0.40.8' > "${NVM_INSTALL_VERSION_EVIDENCE:?}"
FAKE_INSTALLER
}

case "$retry_count" in
    ''|*[!0-9]*|0)
        retry_valid=0
        ;;
    *)
        retry_valid=1
        ;;
esac

if [ "$saw_fail" -ne 1 ] || \
    [ "$saw_show_error" -ne 1 ] || \
    [ "$saw_location" -ne 1 ] || \
    [ "$retry_valid" -ne 1 ]; then
    printf '%s\n' 'curl double requires fail, show-error, location, and retry options' >&2
    exit 64
fi

printf '%s\n' "$retry_count" > "${CURL_FLAGS_EVIDENCE:?}"

case "$url" in
    "$nvm_url")
        printf '%s\n' "$url" > "${CURL_URL_EVIDENCE:?}"
        printf '%s\n' "${output:-stdout}" > "${CURL_OUTPUT_EVIDENCE:?}"

        if [ "${CURL_SHOULD_FAIL:-0}" = '1' ]; then
            printf '%s\n' 'curl: simulated download failure' >&2
            exit 22
        fi

        if [ -z "$output" ] || [ "$output" = '-' ]; then
            emit_installer
        else
            emit_installer > "$output"
        fi
        ;;
    "$bitwarden_url")
        if [ -z "$output" ] || [ "$output" = '-' ]; then
            printf '%s\n' 'Bitwarden curl requires a file output' >&2
            exit 64
        fi
        printf '%s\n' 'offline Bitwarden archive fixture' > "$output"
        ;;
    *)
        printf 'unexpected curl URL: %s\n' "$url" >&2
        exit 64
        ;;
esac
FAKE_CURL

    cat > "$contract_root/bin/npm" <<'EOF'
#!/bin/sh

exit 0
EOF

    cat > "$contract_root/bin/sha512sum" <<'EOF'
#!/bin/sh

set -eu

if [ "$#" -ne 2 ] || [ "$1" != '-c' ] || [ "$2" != '-' ]; then
    exit 64
fi

set -- $(cat)
[ "$#" -eq 2 ] && [ -f "$2" ] || exit 64
printf '%s: OK\n' "$2"
EOF

    cat > "$failure_root/home/.nvm/nvm.sh" <<'EOF'
nvm() {
    printf '%s\n' "$*" >> "${NVM_INVOCATIONS:?}"
    return 0
}
EOF

    chmod +x "$contract_root/bin/"* "$failure_root/home/.nvm/nvm.sh"

    if output="$(
        env -u TMPDIR \
            -u BASH_VERSION \
            HOME="$direct_root/home" \
            PATH="$contract_root/bin:/usr/bin:/bin" \
            BASH_COMPLETION_EVIDENCE="$direct_root/bash-completion-evidence" \
            CURL_FLAGS_EVIDENCE="$direct_root/curl-flags-evidence" \
            CURL_OUTPUT_EVIDENCE="$direct_root/curl-output-evidence" \
            CURL_URL_EVIDENCE="$direct_root/curl-url-evidence" \
            NVM_INSTALL_VERSION_EVIDENCE="$direct_root/nvm-install-version-evidence" \
            NVM_INVOCATIONS="$direct_root/nvm-invocations" \
            SUDO_INVOCATION="$direct_root/sudo-invocation" \
            TMPDIR_VALUE="$direct_root/tmpdir-value" \
            sh "$repository_root/scripts/alpine/nodejs.sh" 2>&1
    )"; then
        :
    else
        failures+=("Alpine Node.js installer must complete under direct sh without sourcing Bash-only completion: $output")
    fi

    if [ -e "$direct_root/bash-completion-evidence" ]; then
        failures+=('direct sh execution must skip NVM Bash completion')
    fi

    if [ ! -x "$direct_root/home/.nvm/nvm.sh" ]; then
        failures+=('the downloaded NVM installer must run and create executable nvm.sh')
    fi

    if [ ! -s "$direct_root/curl-flags-evidence" ]; then
        failures+=('curl must use fail, show-error, location, and retry options')
    fi

    if [ ! -s "$direct_root/curl-url-evidence" ] || \
        [ "$(cat "$direct_root/curl-url-evidence" 2>/dev/null || :)" != 'https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh' ]; then
        failures+=('curl must request the exact NVM v0.40.8 installer URL')
    fi

    if [ ! -s "$direct_root/nvm-install-version-evidence" ] || \
        [ "$(cat "$direct_root/nvm-install-version-evidence" 2>/dev/null || :)" != 'v0.40.8' ]; then
        failures+=('the NVM v0.40.8 installer output must be executed')
    fi

    if [ ! -s "$direct_root/curl-output-evidence" ]; then
        failures+=('curl did not report its installer output destination')
    else
        curl_output="$(cat "$direct_root/curl-output-evidence")"
        if [ "$curl_output" = 'stdout' ] || [ "$curl_output" = '-' ]; then
            failures+=('the NVM installer must be downloaded to a temporary file instead of piped to bash')
        elif [ -e "$curl_output" ]; then
            failures+=('the temporary NVM installer must be removed after direct sh execution')
        fi
    fi

    if [ ! -s "$direct_root/sudo-invocation" ] || \
        [ "$(sed -n '1,3p' "$direct_root/sudo-invocation" 2>/dev/null || :)" != $'apk\nadd\n--no-cache' ]; then
        failures+=('Alpine Node.js prerequisites were not installed through sudo apk add --no-cache')
    fi

    for package in "${required_packages[@]}"; do
        if ! grep -Fqx -- "$package" "$direct_root/sudo-invocation" 2>/dev/null; then
            failures+=("Alpine Node.js prerequisites are missing $package")
        fi
    done

    if output="$(
        env -u TMPDIR \
            HOME="$bash_root/home" \
            PATH="$contract_root/bin:/usr/bin:/bin" \
            BASH_COMPLETION_EVIDENCE="$bash_root/bash-completion-evidence" \
            CURL_FLAGS_EVIDENCE="$bash_root/curl-flags-evidence" \
            CURL_OUTPUT_EVIDENCE="$bash_root/curl-output-evidence" \
            CURL_URL_EVIDENCE="$bash_root/curl-url-evidence" \
            NVM_INSTALL_VERSION_EVIDENCE="$bash_root/nvm-install-version-evidence" \
            NVM_INVOCATIONS="$bash_root/nvm-invocations" \
            SUDO_INVOCATION="$bash_root/sudo-invocation" \
            TMPDIR_VALUE="$bash_root/tmpdir-value" \
            bash "$repository_root/scripts/alpine/nodejs.sh" 2>&1
    )"; then
        :
    else
        failures+=("Alpine Node.js installer must complete under Bash: $output")
    fi

    if [ ! -s "$bash_root/bash-completion-evidence" ]; then
        failures+=('Bash execution must source NVM Bash completion')
    else
        IFS='|' read -r completion_version sourced_bash_version < "$bash_root/bash-completion-evidence"
        if [ "$completion_version" != 'v0.40.8' ] || [ -z "$sourced_bash_version" ]; then
            failures+=('Bash completion must record NVM v0.40.8 and non-empty BASH_VERSION evidence')
        fi
    fi

    if ! grep -Fqx -- 'install -s node' "$bash_root/nvm-invocations" 2>/dev/null; then
        failures+=('Alpine Node.js must install the latest node alias from source with nvm install -s node')
    fi

    if [ ! -s "$bash_root/tmpdir-value" ] || \
        [ "$(cat "$bash_root/tmpdir-value" 2>/dev/null || :)" != '/tmp' ]; then
        failures+=('Alpine Node.js must default an unset TMPDIR to /tmp before invoking nvm')
    fi

    if [ -s "$bash_root/curl-output-evidence" ]; then
        curl_output="$(cat "$bash_root/curl-output-evidence")"
        if [ "$curl_output" != 'stdout' ] && [ "$curl_output" != '-' ] && [ -e "$curl_output" ]; then
            failures+=('the temporary NVM installer must be removed after Bash execution')
        fi
    fi

    if output="$(
        env \
            HOME="$failure_root/home" \
            PATH="$contract_root/bin:/usr/bin:/bin" \
            TMPDIR="$failure_root/tmp" \
            BASH_COMPLETION_EVIDENCE="$failure_root/bash-completion-evidence" \
            CURL_FLAGS_EVIDENCE="$failure_root/curl-flags-evidence" \
            CURL_OUTPUT_EVIDENCE="$failure_root/curl-output-evidence" \
            CURL_SHOULD_FAIL=1 \
            CURL_URL_EVIDENCE="$failure_root/curl-url-evidence" \
            NVM_INSTALL_VERSION_EVIDENCE="$failure_root/nvm-install-version-evidence" \
            NVM_INVOCATIONS="$failure_root/nvm-invocations" \
            SUDO_INVOCATION="$failure_root/sudo-invocation" \
            TMPDIR_VALUE="$failure_root/tmpdir-value" \
            sh "$repository_root/scripts/alpine/nodejs.sh" 2>&1
    )"; then
        failures+=("a failed curl download must fail the installer instead of falling through to an old NVM: $output")
    fi

    if [ -s "$failure_root/nvm-invocations" ]; then
        failures+=('a failed curl download must stop before invoking a pre-existing NVM')
    fi

    if [ -s "$failure_root/curl-output-evidence" ]; then
        curl_output="$(cat "$failure_root/curl-output-evidence")"
        if [ "$curl_output" != 'stdout' ] && [ "$curl_output" != '-' ] && [ -e "$curl_output" ]; then
            failures+=('the temporary NVM installer must be removed after curl fails')
        fi
    fi

    if [ "${#failures[@]}" -ne 0 ]; then
        printf '%s\n' 'installer contract failure:' >&2
        printf ' - %s\n' "${failures[@]}" >&2
        exit 1
    fi
}

assert_downloaders_checked_before_first_use() {
    local file="$1"
    local dependency_line
    local downloader_line

    dependency_line="$(
        awk '/^[[:space:]]*check_dependencies[[:space:]]*$/ { print NR; exit }' "$file"
    )"
    downloader_line="$(
        awk '
            /\$\((curl|wget)[[:space:]]/ ||
            /^[[:space:]]*(if[[:space:]]+![[:space:]]+)?(curl|wget)[[:space:]]/ {
                print NR
                exit
            }
        ' "$file"
    )"

    [ -n "$dependency_line" ] || fail "missing check_dependencies call in $file"
    [ -n "$downloader_line" ] || fail "missing curl/wget use in $file"
    if [ "$dependency_line" -ge "$downloader_line" ]; then
        fail "check_dependencies runs at line $dependency_line after downloader use at line $downloader_line in $file"
    fi
}

for file in \
    "$repository_root/scripts/alpine/cursor-ide.sh" \
    "$repository_root/scripts/debian/cursor-ide.sh" \
    "$repository_root/scripts/unix/cursor-ide.sh"; do
    assert_downloaders_checked_before_first_use "$file"
done

for file in \
    "$repository_root/scripts/alpine/nodejs.sh" \
    "$repository_root/scripts/debian/nodejs.sh"; do
    rg -q --fixed-strings 'nvm-sh/nvm/v0.40.8/install.sh' "$file" || \
        fail "nvm installer is not pinned to v0.40.8 in $file"
done

assert_alpine_nodejs_source_build_contract
assert_act_retries_complete_installer_pipeline
assert_alpine_base_packages_exclude_bitwarden_runtime
assert_alpine_bitwarden_supported_runtime_contract
assert_alpine_bitwarden_lock_integrity_contract

printf '%s\n' 'Installer downloader, version, privilege, Alpine source-build, and Bitwarden runtime contracts passed.'
