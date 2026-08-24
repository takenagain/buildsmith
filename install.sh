#!/bin/bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

cleanup_bootstrap_repository() {
    if [ -n "${BUILDSMITH_BOOTSTRAP_DIR:-}" ] && [ -d "$BUILDSMITH_BOOTSTRAP_DIR" ]; then
        rm -rf -- "$BUILDSMITH_BOOTSTRAP_DIR"
    fi
}

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
    Linux)
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/alpine-release ]; then
            echo "alpine"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        elif [ -f /etc/arch-release ] || grep -qx 'ID=arch' /etc/os-release 2>/dev/null; then
            echo "arch"
        else
            echo "unknown-linux"
        fi
        ;;
    Darwin)
        echo "darwin"
        ;;
    *)
        echo "unknown"
        ;;
    esac
}

# Install make based on OS
install_make() {
    local os=$(detect_os)

    echo_info "Detecting operating system..."
    echo_info "Detected OS: $os"

    # Check if the bootstrap dependencies are already installed
    if command -v make &> /dev/null && command -v curl &> /dev/null && command -v git &> /dev/null; then
        echo_info "make, curl, and git are already installed"
        return 0
    fi

    echo_info "Installing make, curl, and git..."

    case $os in
        debian)
            run_privileged apt-get update
            run_privileged apt-get install -y make build-essential ca-certificates curl git
            ;;
        alpine)
            run_privileged apk add --no-cache make build-base ca-certificates curl git
            ;;
        redhat)
            run_privileged yum install -y make gcc gcc-c++ ca-certificates curl git
            ;;
        arch)
            run_privileged pacman -Syu --needed --noconfirm base-devel ca-certificates curl git sudo
            ;;
        darwin)
            # On macOS, make comes with Xcode Command Line Tools
            if ! command -v xcode-select &> /dev/null; then
                echo_info "Installing Xcode Command Line Tools..."
                xcode-select --install
            fi
            if ! command -v curl &> /dev/null; then
                if command -v brew &> /dev/null; then
                    echo_info "Installing curl with Homebrew..."
                    brew install curl
                    local brew_curl_prefix
                    brew_curl_prefix="$(brew --prefix curl)"
                    export PATH="$brew_curl_prefix/bin:$PATH"
                else
                    echo_error "curl is required, but Homebrew is unavailable to install it"
                    exit 1
                fi
            fi
            ;;
        *)
            echo_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac

    if ! command -v make &> /dev/null || ! command -v curl &> /dev/null || ! command -v git &> /dev/null; then
        echo_error "Failed to install required bootstrap dependencies: make, curl, and git"
        exit 1
    fi

    echo_info "make, curl, and git installed successfully"
}

# Install Rust
install_rust() {
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    local CARGO_BIN_DIR="$cargo_home/bin"

    export PATH="$CARGO_BIN_DIR:$PATH"

    echo_info "Checking for Rust installation..."

    if command -v rustc &> /dev/null; then
        echo_info "Rust is already installed (version: $(rustc --version))"
        return 0
    fi

    echo_info "Installing Rust..."

    # Install Rust using rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Source cargo environment
    if [ -f "$cargo_home/env" ]; then
        source "$cargo_home/env"
    fi

    echo_info "Rust installed successfully (version: $(rustc --version))"
}

# Main installation process
main() {
    echo_info "Starting dev-box-setup installation..."

    if [ -n "${BUILDSMITH_BOOTSTRAP_DIR:-}" ]; then
        trap cleanup_bootstrap_repository EXIT
    fi

    # Get the directory where the script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

    # A streamed raw-GitHub invocation has no repository checkout beside this
    # script. Bootstrap a temporary checkout, then rerun the normal installer.
    if [ ! -f "$SCRIPT_DIR/Makefile" ]; then
        install_make

        local bootstrap_dir
        bootstrap_dir="$(mktemp -d "${TMPDIR:-/tmp}/buildsmith-bootstrap.XXXXXX")"
        if ! git clone --depth 1 "${BUILDSMITH_REPOSITORY_URL:-https://github.com/takenagain/buildsmith.git}" "$bootstrap_dir"; then
            rm -rf -- "$bootstrap_dir"
            echo_error "Failed to clone the Buildsmith repository"
            exit 1
        fi

        exec env BUILDSMITH_BOOTSTRAP_DIR="$bootstrap_dir" bash "$bootstrap_dir/install.sh"
    fi

    # Change to script directory
    cd "$SCRIPT_DIR"

    # Install make
    install_make

    # Install Rust
    install_rust

    # Ensure cargo is in PATH for the current session
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    local CARGO_BIN_DIR="$cargo_home/bin"
    export PATH="$CARGO_BIN_DIR:$PATH"
    if [ -f "$cargo_home/env" ]; then
        source "$cargo_home/env"
    fi

    # Run make commands
    echo_info "Installing system dependencies..."
    #make install-deps

    echo_info "Building and running the installer..."
    if [ -n "${CI:-}" ]; then
        echo_info "CI environment detected - skipping interactive mode"
        make build
    else
        make install
    fi

    echo_info "Installation completed successfully!"
    echo_info "You may need to restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to ensure all environment variables are loaded."
}

# Run main function
main
