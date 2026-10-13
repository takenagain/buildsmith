#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Run Docker Desktop setup as your desktop user, not root." >&2
    exit 1
fi

if [ "$(uname -m)" != 'x86_64' ]; then
    echo "Docker Desktop's Arch package is available only for x86_64." >&2
    exit 1
fi

sudo pacman -Syu --needed --noconfirm ca-certificates curl docker

temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT

release_notes="$temp_dir/release-notes.html"
checksums="$temp_dir/checksums.txt"
package_path="$temp_dir/docker-desktop-x86_64.pkg.tar.zst"

curl --fail --silent --show-error --location --retry 3 \
    --output "$release_notes" \
    https://docs.docker.com/desktop/release-notes/

package_url="$(grep -Eo 'https://desktop\.docker\.com/linux/main/amd64/[0-9]+/docker-desktop-x86_64\.pkg\.tar\.zst' "$release_notes" | head -n 1 || true)"
if [ -z "$package_url" ]; then
    echo "Could not find Docker's current Arch package in the official release notes." >&2
    exit 1
fi

checksums_url="${package_url%/*}/checksums.txt"
curl --fail --silent --show-error --location --retry 3 \
    --output "$checksums" "$checksums_url"
curl --fail --silent --show-error --location --retry 3 \
    --output "$package_path" "$package_url"

expected_sha256="$(awk '$2 == "*docker-desktop-x86_64.pkg.tar.zst" { print $1; exit }' "$checksums")"
if [[ ! "$expected_sha256" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "Could not find Docker Desktop's Arch package checksum." >&2
    exit 1
fi
printf '%s  %s\n' "$expected_sha256" "$package_path" | sha256sum --check -

sudo pacman -U --noconfirm "$package_path"
systemctl --user enable docker-desktop.service

echo "Docker Desktop is installed and enabled for this user. Launch it from your desktop session and accept Docker's terms on first use."
