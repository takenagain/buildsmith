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

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
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
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    else
        echo "unknown"
    fi
}

# Install make based on OS
install_make() {
    local os=$(detect_os)

    echo_info "Detecting operating system..."
    echo_info "Detected OS: $os"

    # Check if make is already installed
    if command -v make &> /dev/null; then
        echo_info "make is already installed"
        return 0
    fi

    echo_info "Installing make..."

    case $os in
        debian)
            run_privileged apt-get update
            run_privileged apt-get install -y make build-essential
            ;;
        alpine)
            run_privileged apk add --no-cache make build-base
            ;;
        redhat)
            run_privileged yum install -y make gcc gcc-c++
            ;;
        arch)
            run_privileged pacman -Syu --needed --noconfirm base-devel ca-certificates curl git
            ;;
        darwin)
            # On macOS, make comes with Xcode Command Line Tools
            if ! command -v xcode-select &> /dev/null; then
                echo_info "Installing Xcode Command Line Tools..."
                xcode-select --install
            fi
            ;;
        *)
            echo_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac

    echo_info "make installed successfully"
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

    # Get the directory where the script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

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
