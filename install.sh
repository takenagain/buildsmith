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

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/alpine-release ]; then
            echo "alpine"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
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
            sudo apt-get update
            sudo apt-get install -y make build-essential
            ;;
        alpine)
            sudo apk add --no-cache make build-base
            ;;
        redhat)
            sudo yum install -y make gcc gcc-c++
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
    echo_info "Checking for Rust installation..."

    if command -v rustc &> /dev/null; then
        echo_info "Rust is already installed (version: $(rustc --version))"
        return 0
    fi

    echo_info "Installing Rust..."

    # Install Rust using rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Source cargo environment
    source "$HOME/.cargo/env"

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
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    # Run make commands
    echo_info "Installing system dependencies..."
    make install-deps

    echo_info "Building and running the installer..."
    make install

    echo_info "Installation completed successfully!"
    echo_info "You may need to restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to ensure all environment variables are loaded."
}

# Run main function
main
