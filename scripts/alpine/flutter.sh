#!/bin/sh

set -eu

# gcompat is Alpine's maintained glibc compatibility package.
apk update
java_package="$(apk search -x 'openjdk[0-9]*-jdk' | sort -V | tail -n 1 | sed 's/-[0-9].*$//')"
if [ -z "$java_package" ]; then
    echo "Unable to locate the current Alpine OpenJDK package." >&2
    exit 1
fi
apk add --no-cache bash curl gcompat git "$java_package" unzip xz zip

fvm_installer="$(mktemp "${TMPDIR:-/tmp}/fvm-install.XXXXXX")"
trap 'rm -f "$fvm_installer"' EXIT
curl -fsSL --retry 3 --retry-all-errors -o "$fvm_installer" \
    https://fvm.app/install.sh
bash "$fvm_installer"
export PATH="$HOME/.fvm/bin:$PATH"

if ! grep -q 'alias flutter=' "$HOME/.profile" 2>/dev/null; then
    printf '%s\n' \
        'export PATH="$HOME/.fvm/bin:$PATH"' \
        'alias flutter="fvm flutter"' >> "$HOME/.profile"
fi

fvm install stable
fvm global stable
