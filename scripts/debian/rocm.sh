#!/usr/bin/env bash

set -euo pipefail

die() {
    printf 'ROCm installation failed: %s\n' "$*" >&2
    exit 1
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        die "root privileges are required and sudo is unavailable"
    fi
}

[ -r /etc/os-release ] || die "/etc/os-release is unavailable"

# shellcheck disable=SC1091
. /etc/os-release

[ "${ID:-}" = "ubuntu" ] || die "only Ubuntu is supported by this AMDGPU installer path"

ubuntu_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
case "$ubuntu_codename" in
    resolute|noble|jammy) ;;
    *) die "unsupported Ubuntu codename: ${ubuntu_codename:-unknown}" ;;
esac

amdgpu_install_version="31.40.1"
amdgpu_install_package="amdgpu-install_31.40.1.314001-1_all.deb"
amdgpu_install_url="https://repo.radeon.com/amdgpu-install/${amdgpu_install_version}/ubuntu/${ubuntu_codename}/${amdgpu_install_package}"

temp_dir="$(mktemp -d)"
cleanup() {
    rm -rf -- "$temp_dir"
}
trap cleanup EXIT

package_path="${temp_dir}/${amdgpu_install_package}"

run_as_root apt-get update
run_as_root apt-get install -y --no-install-recommends ca-certificates curl
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --output "$package_path" "$amdgpu_install_url"
run_as_root apt-get install -y "$package_path"
run_as_root amdgpu-install --usecase=rocm --gfxversion=auto --no-dkms
