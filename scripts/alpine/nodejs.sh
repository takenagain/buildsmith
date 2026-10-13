#!/bin/sh

set -eu

export TMPDIR="${TMPDIR:-/tmp}"

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bitwarden_assets="$script_dir/bitwarden-cli"
bitwarden_cli_version='2026.9.1'
bitwarden_cli_url="https://registry.npmjs.org/@bitwarden/cli/-/cli-${bitwarden_cli_version}.tgz"
bitwarden_cli_sha512='46c9a7b0999d11ccf256c7f9dfb5bc8fc1a5cdb8afad20bd0361dc4b0be28f76e7d15cf8a6c09c2428a3d7d8c9450c60ff85aeec6b9d0b8538e65d939dbdbe18'
bitwarden_node_version='24.21.0'
bitwarden_npm_version='11.19.0'
bitwarden_install_root="$HOME/.local/share/buildsmith/bitwarden-cli"

sudo apk add --no-cache \
    curl \
    bash \
    ca-certificates \
    openssl \
    ncurses \
    coreutils \
    python3 \
    make \
    gcc \
    g++ \
    libgcc \
    linux-headers \
    grep \
    util-linux \
    binutils \
    findutils

# Install the current nvm release.
nvm_installer="$(mktemp "${TMPDIR}/nvm-install.XXXXXX")"
trap 'rm -f -- "$nvm_installer"' 0
curl --fail --show-error --location --retry 3 \
    --output "$nvm_installer" \
    https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh
bash "$nvm_installer"
rm -f -- "$nvm_installer"
trap - 0

# Configure nvm in current session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
if [ -n "${BASH_VERSION:-}" ] && [ -s "$NVM_DIR/bash_completion" ]; then
    \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

# Bitwarden CLI 2026.9.1 supports Node >=22 and npm >=10. Keep its runtime
# isolated from Alpine's packages and from the moving developer default.
nvm install -s "$bitwarden_node_version"
nvm use "$bitwarden_node_version"

bitwarden_node_bin="$NVM_DIR/versions/node/v${bitwarden_node_version}/bin"
bitwarden_node="$bitwarden_node_bin/node"
bitwarden_npm="$bitwarden_node_bin/npm"

if [ "$("$bitwarden_node" --version)" != "v${bitwarden_node_version}" ]; then
    echo "Expected Bitwarden Node.js v${bitwarden_node_version}." >&2
    exit 1
fi

if [ "$(PATH="$bitwarden_node_bin:$PATH" "$bitwarden_npm" --version)" != "$bitwarden_npm_version" ]; then
    echo "Expected Bitwarden npm ${bitwarden_npm_version}." >&2
    exit 1
fi

mkdir -p "$HOME/.local/bin" "$bitwarden_install_root"
cp "$bitwarden_assets/package.json" "$bitwarden_install_root/package.json"
cp "$bitwarden_assets/package-lock.json" "$bitwarden_install_root/package-lock.json"

bitwarden_cli_archive="$bitwarden_install_root/bitwarden-cli.tgz"
curl --proto '=https' --tlsv1.2 \
    --fail --show-error --location --retry 3 \
    --output "$bitwarden_cli_archive" \
    "$bitwarden_cli_url"
printf '%s  %s\n' "$bitwarden_cli_sha512" "$bitwarden_cli_archive" | sha512sum -c -

(
    cd "$bitwarden_install_root"
    PATH="$bitwarden_node_bin:$PATH"
    export PATH
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
        "$bitwarden_npm" ci --ignore-scripts --omit=dev --loglevel=error
)

cp "$bitwarden_assets/bw" "$HOME/.local/bin/bw"
chmod +x "$HOME/.local/bin/bw"

installed_bitwarden_cli_version="$("$HOME/.local/bin/bw" --version)"
if [ "$installed_bitwarden_cli_version" != "$bitwarden_cli_version" ]; then
    echo "Expected Bitwarden CLI ${bitwarden_cli_version}, got ${installed_bitwarden_cli_version}." >&2
    exit 1
fi

# Install and select the latest available Node.js release for development.
nvm install -s node
nvm use node
npm install -g npm@latest
npm install -g npm-check-updates

echo "Bitwarden CLI ${installed_bitwarden_cli_version} installed with Node.js v${bitwarden_node_version} and npm ${bitwarden_npm_version}."
