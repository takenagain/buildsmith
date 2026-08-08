#!/bin/sh

set -eu

# gcompat is Alpine's maintained glibc compatibility package.
apk add --no-cache bash curl gcompat git openjdk21 unzip xz zip

curl -fsSL https://raw.githubusercontent.com/leoafarias/fvm/main/scripts/install.sh | bash
export PATH="$HOME/.fvm/bin:$PATH"

if ! grep -q 'alias flutter=' "$HOME/.profile" 2>/dev/null; then
    printf '%s\n' \
        'export PATH="$HOME/.fvm/bin:$PATH"' \
        'alias flutter="fvm flutter"' >> "$HOME/.profile"
fi

fvm install stable
fvm global stable
