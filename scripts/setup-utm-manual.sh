#!/bin/bash

# Manual UTM Setup Script for LnOS
# This script helps set up a UTM VM manually if automatic import fails

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(pwd)/out"
UTM_NAME="lnos-asahi-$(date +%Y.%m.%d)"
DISK_SIZE_GB="20"
MEMORY_SIZE_MB="4096"
CPU_CORES="4"

print_status "LnOS Manual UTM Setup Helper"
print_status "=============================="
print_status ""

# Check if UTM is installed
if ! command -v utmctl &> /dev/null && [[ ! -d "/Applications/UTM.app" ]]; then
    print_error "UTM is not installed. Please install UTM first."
    exit 1
fi

# Check if we have the required files
if [[ ! -f "$OUTPUT_DIR/${UTM_NAME}.utm/Images/disk0.qcow2" ]]; then
    print_error "Disk image not found. Please run build-utm-asahi.sh first."
    exit 1
fi

if [[ ! -f "$OUTPUT_DIR/${UTM_NAME}.utm/Images/asahi-installer.iso" ]]; then
    print_error "Asahi installer ISO not found. Please run build-utm-asahi.sh first."
    exit 1
fi

print_status "Found required files. Setting up manual UTM configuration..."
print_status ""

print_status "utmctl is available for controlling VMs, but cannot create them."
print_status "Creating minimal configuration for manual import..."
print_status ""

# Create a minimal UTM bundle
MANUAL_UTM_DIR="$OUTPUT_DIR/${UTM_NAME}-manual.utm"
mkdir -p "$MANUAL_UTM_DIR/Images"

# Copy the disk image
cp "$OUTPUT_DIR/${UTM_NAME}.utm/Images/disk0.qcow2" "$MANUAL_UTM_DIR/Images/"

# Copy the Asahi ISO
cp "$OUTPUT_DIR/${UTM_NAME}.utm/Images/asahi-installer.iso" "$MANUAL_UTM_DIR/Images/"

# Create a very basic config
cat > "$MANUAL_UTM_DIR/config.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Backend</key>
    <string>Apple</string>
    <key>ConfigurationVersion</key>
    <integer>1</integer>
    <key>Information</key>
    <dict>
        <key>Name</key>
        <string>LnOS Asahi Linux</string>
        <key>UUID</key>
        <string>$(uuidgen)</string>
    </dict>
    <key>System</key>
    <dict>
        <key>Architecture</key>
        <string>aarch64</string>
        <key>CPU</key>
        <dict>
            <key>CoreCount</key>
            <integer>$CPU_CORES</integer>
        </dict>
        <key>Memory</key>
        <dict>
            <key>MemorySize</key>
            <integer>$MEMORY_SIZE_MB</integer>
        </dict>
    </dict>
    <key>Drives</key>
    <array>
        <dict>
            <key>Identifier</key>
            <string>$(uuidgen)</string>
            <key>ImageName</key>
            <string>disk0.qcow2</string>
            <key>ImageType</key>
            <string>Disk</string>
        </dict>
    </array>
    <key>Networks</key>
    <array>
        <dict>
            <key>Enabled</key>
            <true/>
        </dict>
    </array>
    <key>Displays</key>
    <array>
        <dict>
            <key>PixelsHigh</key>
            <integer>1024</integer>
            <key>PixelsWide</key>
            <integer>1280</integer>
        </dict>
    </array>
</dict>
</plist>
EOF

print_status "Minimal configuration created!"
print_status "Location: $MANUAL_UTM_DIR"
print_status ""
print_status "Note: utmctl can be used to control the VM after it's created:"
print_status "  utmctl list                    # List all VMs"
print_status "  utmctl start <vm-name>         # Start the VM"
print_status "  utmctl stop <vm-name>          # Stop the VM"
print_status "  utmctl status <vm-name>        # Check VM status"

print_status ""
print_status "Manual Setup Instructions:"
print_status "=========================="
print_status ""
print_status "If the automatic import still fails, follow these steps:"
print_status ""
print_status "1. Open UTM"
print_status "2. Click 'Create a New Virtual Machine'"
print_status "3. Choose 'Linux' as the operating system"
print_status "4. Select 'Other Linux (64-bit ARM)' as the architecture"
print_status "5. Set the following specifications:"
print_status "   - Memory: ${MEMORY_SIZE_MB}MB"
print_status "   - CPU Cores: $CPU_CORES"
print_status "   - Storage: Use existing disk image"
print_status "     Path: $OUTPUT_DIR/${UTM_NAME}.utm/Images/disk0.qcow2"
print_status "6. Add the Asahi installer ISO as a CD/DVD drive:"
print_status "   Path: $OUTPUT_DIR/${UTM_NAME}.utm/Images/asahi-installer.iso"
print_status "7. Set the CD/DVD drive to boot first in the VM settings"
print_status "8. Start the VM and install Asahi Linux"
print_status ""
print_status "After Asahi Linux is installed:"
print_status "1. Copy the LnOS scripts from the shared directory"
print_status "2. Run the bootstrap script:"
print_status "   curl -sL https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/utm-templates/asahi-bootstrap.sh | sudo bash"
print_status "3. Reboot and the LnOS installer will start automatically"
print_status ""

# Try to open UTM
if [[ -d "/Applications/UTM.app" ]]; then
    print_status "Opening UTM..."
    open "/Applications/UTM.app"
fi

print_status "Setup complete!" 