#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root directly. It will ask for sudo when needed."
    exit 1
fi

print_status "Installing Cursor IDE for Alpine Linux..."

# Check dependencies and install using apk
check_dependencies() {
    local missing_deps=()

    for cmd in wget curl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "Installing missing dependencies: ${missing_deps[*]}"
        sudo apk update
        sudo apk add "${missing_deps[@]}"
    fi
}

check_dependencies

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_URL="x64"
        ;;
    aarch64|arm64)
        ARCH_URL="arm64"
        ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        print_error "Cursor IDE supports x86_64 and arm64 architectures only."
        exit 1
        ;;
esac

# URLs and file paths
DOWNLOAD_API_URL="https://www.cursor.com/api/download?platform=linux-${ARCH_URL}&releaseTrack=stable"
APPIMAGE_URL="$(curl -fsSL --retry 3 --retry-all-errors "$DOWNLOAD_API_URL" | sed -n 's/.*"downloadUrl":"\([^"]*\)".*/\1/p')"
if [ -z "$APPIMAGE_URL" ]; then
    print_error "Cursor's current download API returned no Linux AppImage URL"
    exit 1
fi
ICON_URL="https://us1.discourse-cdn.com/cursor1/original/2X/f/f7bc157cca4b97c3f0fc83c3c1a7094871a268df.png"
APPIMAGE_FILE="$TEMP_DIR/Cursor.AppImage"
ICON_FILE="$TEMP_DIR/cursor-icon.png"

# Get the script directory to find create-appimage-desktop.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATE_DESKTOP_SCRIPT="$SCRIPT_DIR/../create-appimage-desktop.sh"

# If running from current directory, adjust path
if [[ ! -f "$CREATE_DESKTOP_SCRIPT" ]]; then
    CREATE_DESKTOP_SCRIPT="$(pwd)/scripts/create-appimage-desktop.sh"
fi

# Check if create-appimage-desktop.sh exists
if [[ ! -f "$CREATE_DESKTOP_SCRIPT" ]]; then
    print_error "create-appimage-desktop.sh not found at $CREATE_DESKTOP_SCRIPT"
    print_error "Please ensure the script is in the correct location."
    exit 1
fi

# Download Cursor AppImage
print_status "Downloading Cursor IDE AppImage for $ARCH architecture..."
if ! wget -O "$APPIMAGE_FILE" "$APPIMAGE_URL"; then
    print_error "Failed to download Cursor AppImage"
    exit 1
fi

# Download Cursor icon
print_status "Downloading Cursor IDE icon..."
if ! wget -O "$ICON_FILE" "$ICON_URL"; then
    print_warning "Failed to download icon, continuing without it..."
    ICON_FILE=""
fi

# Make sure the AppImage is executable
chmod +x "$APPIMAGE_FILE"

# Install FUSE for AppImage support
print_status "Installing FUSE library for AppImage support..."
if ! apk info -e fuse &> /dev/null; then
    sudo apk add fuse
fi

# Install desktop-file-utils if available
print_status "Installing desktop file utilities..."
if ! command -v update-desktop-database &> /dev/null; then
    if sudo apk add desktop-file-utils &> /dev/null; then
        print_status "Desktop file utilities installed successfully."
    else
        print_warning "Could not install desktop-file-utils. Desktop integration may be limited."
    fi
fi

# Alpine-specific: Install gcompat for better AppImage compatibility
print_status "Installing compatibility libraries..."
if ! apk info -e gcompat &> /dev/null; then
    if sudo apk add gcompat &> /dev/null; then
        print_status "Compatibility libraries installed successfully."
    else
        print_warning "Could not install gcompat. Some AppImages may not work correctly."
    fi
fi

# Enable fuse module if not already loaded
if ! lsmod | grep -q fuse; then
    print_status "Loading FUSE module..."
    if sudo modprobe fuse; then
        print_status "FUSE module loaded successfully."
    else
        print_warning "Could not load FUSE module. AppImage may not work without it."
    fi
fi

# Add fuse to modules to load at boot
if ! grep -q "^fuse$" /etc/modules 2>/dev/null; then
    print_status "Configuring FUSE to load at boot..."
    echo "fuse" | sudo tee -a /etc/modules > /dev/null
fi

# Call create-appimage-desktop.sh
print_status "Setting up desktop integration..."
if [[ -n "$ICON_FILE" ]]; then
    sudo bash "$CREATE_DESKTOP_SCRIPT" "$APPIMAGE_FILE" "$ICON_FILE"
else
    sudo bash "$CREATE_DESKTOP_SCRIPT" "$APPIMAGE_FILE"
fi

print_status "Cursor IDE installation completed successfully!"
print_status "You can now find Cursor in your application menu or run it from the terminal with: cursor"

# Optional: Test the installation
REPLY="N"
if [ "${CI:-0}" != "1" ]; then
    read -r -p "Would you like to test the installation by launching Cursor? (y/N): " -n 1 REPLY || true
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Launching Cursor IDE..."
    /opt/cursor/cursor.AppImage --no-sandbox &
    print_status "Cursor IDE should be starting..."
fi
