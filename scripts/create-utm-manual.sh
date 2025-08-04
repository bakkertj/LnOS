#!/bin/bash

# Manual UTM VM Creation Script for LnOS
# This script provides step-by-step instructions to create the VM manually in UTM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(pwd)/out"
UTM_NAME="lnos-asahi-$(date +%Y.%m.%d)"
DISK_SIZE_GB="20"
MEMORY_SIZE_MB="4096"
CPU_CORES="4"

print_status "LnOS Manual UTM VM Creation Guide"
print_status "=================================="
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

print_status "Found required files. Follow these steps to create the VM manually:"
print_status ""

# Display file paths
print_status "Required files:"
print_status "  Disk Image: $OUTPUT_DIR/${UTM_NAME}.utm/Images/disk0.qcow2"
print_status "  Asahi ISO:  $OUTPUT_DIR/${UTM_NAME}.utm/Images/asahi-installer.iso"
print_status ""

print_step "Step 1: Open UTM"
print_status "  - Launch UTM from Applications or Spotlight"
print_status ""

print_step "Step 2: Create New Virtual Machine"
print_status "  - Click 'Create a New Virtual Machine' or '+' button"
print_status ""

print_step "Step 3: Choose Operating System"
print_status "  - Select 'Linux' as the operating system"
print_status "  - Click 'Continue'"
print_status ""

print_step "Step 4: Choose Architecture"
print_status "  - Select 'Other Linux (64-bit ARM)' or 'aarch64'"
print_status "  - Click 'Continue'"
print_status ""

print_step "Step 5: Configure System"
print_status "  - Memory: ${MEMORY_SIZE_MB}MB (4GB)"
print_status "  - CPU Cores: $CPU_CORES"
print_status "  - Click 'Continue'"
print_status ""

print_step "Step 6: Configure Storage"
print_status "  - Select 'Use existing disk image'"
print_status "  - Click 'Browse' and navigate to:"
print_status "    $OUTPUT_DIR/${UTM_NAME}.utm/Images/disk0.qcow2"
print_status "  - Click 'Continue'"
print_status ""

print_step "Step 7: Configure Network"
print_status "  - Select 'Shared Network' (default)"
print_status "  - Click 'Continue'"
print_status ""

print_step "Step 8: Configure Display"
print_status "  - Select 'VirtIO-GPU' or 'VirtIO'"
print_status "  - Resolution: 1280x1024 (or your preference)"
print_status "  - Click 'Continue'"
print_status ""

print_step "Step 9: Name the VM"
print_status "  - Name: 'LnOS Asahi Linux'"
print_status "  - Click 'Save'"
print_status ""

print_step "Step 10: Add Asahi Installer ISO"
print_status "  - Right-click on the created VM"
print_status "  - Select 'Edit' or 'Settings'"
print_status "  - Go to 'Drives' tab"
print_status "  - Click '+' to add a new drive"
print_status "  - Select 'CD/DVD' as type"
print_status "  - Browse to: $OUTPUT_DIR/${UTM_NAME}.utm/Images/asahi-installer.iso"
print_status "  - Set as 'Removable' and enable it"
print_status "  - Click 'Save'"
print_status ""

print_step "Step 11: Configure Boot Order"
print_status "  - In VM settings, go to 'System' tab"
print_status "  - Set CD/DVD drive to boot first"
print_status "  - Click 'Save'"
print_status ""

print_step "Step 12: Start the VM"
print_status "  - Click 'Start' on the VM"
print_status "  - The Asahi Linux installer should boot"
print_status ""

print_status ""
print_status "Installation Process:"
print_status "======================"
print_status ""

print_step "Step 13: Install Asahi Linux"
print_status "  - Follow the Asahi Linux installation wizard"
print_status "  - Choose 'Install Asahi Linux'"
print_status "  - Select the disk (/dev/vda)"
print_status "  - Set up user account and passwords"
print_status "  - Wait for installation to complete"
print_status ""

print_step "Step 14: Install LnOS"
print_status "  - After Asahi Linux boots, login as your user"
print_status "  - Run the bootstrap script:"
print_status "    curl -sL https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/utm-templates/asahi-bootstrap.sh | sudo bash"
print_status "  - Reboot the VM"
print_status "  - LnOS installer will start automatically"
print_status ""

print_status ""
print_status "Alternative: Use utmctl to control the VM"
print_status "=========================================="
print_status ""

if command -v utmctl &> /dev/null; then
    print_status "Once the VM is created, you can use utmctl to control it:"
    print_status "  utmctl list                    # List all VMs"
    print_status "  utmctl start 'LnOS Asahi Linux'  # Start the VM"
    print_status "  utmctl stop 'LnOS Asahi Linux'   # Stop the VM"
    print_status "  utmctl status 'LnOS Asahi Linux' # Check status"
    print_status ""
fi

print_status ""
print_status "Troubleshooting:"
print_status "================"
print_status ""

print_status "If the VM won't start:"
print_status "  - Check that the disk image path is correct"
print_status "  - Ensure the Asahi ISO is properly mounted"
print_status "  - Try increasing memory to 6GB or 8GB"
print_status "  - Check UTM console for error messages"
print_status ""

print_status "If Asahi installer doesn't boot:"
print_status "  - Verify the ISO file is not corrupted"
print_status "  - Try downloading a fresh copy from asahilinux.org"
print_status "  - Check that CD/DVD is set to boot first"
print_status ""

print_status "If LnOS installer doesn't start:"
print_status "  - Check network connectivity in the VM"
print_status "  - Run the bootstrap script manually"
print_status "  - Check the shared directory is accessible"
print_status ""

# Try to open UTM
if [[ -d "/Applications/UTM.app" ]]; then
    print_status ""
    print_status "Opening UTM..."
    open "/Applications/UTM.app"
fi

print_status ""
print_status "Manual setup guide complete!"
print_status "Follow the steps above to create your LnOS VM." 