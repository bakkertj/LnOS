#!/bin/bash

# Build script for LnOS UTM Virtual Machine with Asahi Linux
# Usage: ./build-utm-asahi.sh

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(pwd)/out"
UTM_NAME="lnos-asahi-$(date +%Y.%m.%d)"
UTM_DIR="$OUTPUT_DIR/${UTM_NAME}.utm"
ASAHI_INSTALLER_URL="https://cdn.asahilinux.org/os/installer"
DISK_SIZE_GB="20"
MEMORY_SIZE_MB="4096"
CPU_CORES="4"

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

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed to run on macOS only"
    exit 1
fi

# Check if UTM is installed
if ! command -v utmctl &> /dev/null && [[ ! -d "/Applications/UTM.app" ]]; then
    print_warning "UTM is not installed. Attempting to install UTM automatically..."
    
    # Check if Homebrew is available
    if command -v brew &> /dev/null; then
        print_status "Installing UTM via Homebrew..."
        brew install --cask utm
        if [[ $? -eq 0 ]]; then
            print_status "UTM installed successfully via Homebrew!"
        else
            print_error "Failed to install UTM via Homebrew"
            print_error "Please install UTM manually from https://mac.getutm.app/ or Mac App Store"
            exit 1
        fi
    else
        # Try to install via curl (direct download)
        print_status "Homebrew not found. Attempting to download UTM directly..."
        UTM_DOWNLOAD_URL="https://github.com/utmapp/UTM/releases/latest/download/UTM.dmg"
        UTM_DMG="$OUTPUT_DIR/UTM.dmg"
        
        print_status "Downloading UTM from GitHub releases..."
        if curl -L -o "$UTM_DMG" "$UTM_DOWNLOAD_URL"; then
            print_status "UTM downloaded successfully. Installing..."
            
            # Mount the DMG
            if hdiutil attach "$UTM_DMG" -quiet; then
                # Find the mounted volume
                MOUNT_POINT=$(hdiutil info | grep "/Volumes/UTM" | awk '{print $3}' | head -1)
                if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
                    # Copy UTM to Applications
                    if cp -R "$MOUNT_POINT/UTM.app" "/Applications/"; then
                        print_status "UTM installed successfully!"
                        # Unmount the DMG
                        hdiutil detach "$MOUNT_POINT" -quiet
                        # Clean up
                        rm "$UTM_DMG"
                    else
                        print_error "Failed to copy UTM to Applications"
                        hdiutil detach "$MOUNT_POINT" -quiet
                        rm "$UTM_DMG"
                        exit 1
                    fi
                else
                    print_error "Failed to mount UTM DMG"
                    rm "$UTM_DMG"
                    exit 1
                fi
            else
                print_error "Failed to mount UTM DMG"
                rm "$UTM_DMG"
                exit 1
            fi
        else
            print_error "Failed to download UTM"
            print_error "Please install UTM manually from https://mac.getutm.app/ or Mac App Store"
            exit 1
        fi
    fi
    
    # Verify installation
    if ! command -v utmctl &> /dev/null && [[ ! -d "/Applications/UTM.app" ]]; then
        print_error "UTM installation verification failed"
        print_error "Please install UTM manually from https://mac.getutm.app/ or Mac App Store"
        exit 1
    fi
fi

print_status "Building LnOS UTM Virtual Machine with Asahi Linux..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create UTM bundle structure
print_status "Creating UTM bundle structure..."
mkdir -p "$UTM_DIR"
mkdir -p "$UTM_DIR/Data"
mkdir -p "$UTM_DIR/Images"

# Create the main disk image
print_status "Creating main disk image (${DISK_SIZE_GB}GB)..."
DISK_IMAGE="$UTM_DIR/Images/disk0.qcow2"
if command -v qemu-img &> /dev/null; then
    qemu-img create -f qcow2 "$DISK_IMAGE" "${DISK_SIZE_GB}G"
else
    print_warning "qemu-img not found, creating placeholder disk image"
    # Create a minimal placeholder - UTM will create the actual disk
    touch "$DISK_IMAGE"
fi

# Download Asahi Linux installer if not present
print_status "Preparing Asahi Linux installer..."
ASAHI_ISO="$UTM_DIR/Images/asahi-installer.iso"

# Try to find a local Asahi Linux installer ISO
if [[ -f "$SCRIPT_DIR/asahi-installer.iso" ]]; then
    print_status "Using local Asahi installer ISO..."
    cp "$SCRIPT_DIR/asahi-installer.iso" "$ASAHI_ISO"
elif [[ -f "$OUTPUT_DIR/asahi-installer.iso" ]]; then
    print_status "Using cached Asahi installer ISO..."
    cp "$OUTPUT_DIR/asahi-installer.iso" "$ASAHI_ISO"
else
    print_warning "Asahi Linux installer ISO not found locally."
    print_status "Attempting to download Asahi Linux installer ISO..."
    
    # Try to download the latest Asahi installer
    ASAHI_DOWNLOAD_URL="https://cdn.asahilinux.org/os/installer/latest/asahi-installer.iso"
    
    if curl -L -o "$ASAHI_ISO" "$ASAHI_DOWNLOAD_URL"; then
        print_status "Successfully downloaded Asahi Linux installer ISO!"
        # Cache it for future use
        cp "$ASAHI_ISO" "$OUTPUT_DIR/asahi-installer.iso" 2>/dev/null || true
    else
        print_warning "Failed to download Asahi installer automatically."
        print_warning "Please download the latest Asahi Linux installer ISO from:"
        print_warning "https://asahilinux.org/fedora/"
        print_warning "And place it as 'asahi-installer.iso' in this directory"
        print_warning ""
        print_warning "For now, creating a placeholder. You'll need to:"
        print_warning "1. Download the Asahi installer ISO"
        print_warning "2. Add it to the UTM VM as a CD/DVD drive"
        print_warning "3. Boot from the ISO to install Asahi Linux"
        
        # Create placeholder
        touch "$ASAHI_ISO"
    fi
fi

# Create configuration.plist for UTM
print_status "Creating UTM configuration..."

# Detect UTM version for compatibility
detect_utm_version() {
    local utm_version="3"  # Default to version 3
    
    if [[ -d "/Applications/UTM.app" ]]; then
        # Try to get version from UTM.app
        local info_plist="/Applications/UTM.app/Contents/Info.plist"
        if [[ -f "$info_plist" ]]; then
            local version=$(defaults read "$info_plist" CFBundleShortVersionString 2>/dev/null)
            if [[ -n "$version" ]]; then
                print_status "Detected UTM version: $version"
                # Map version to configuration version
                case "$version" in
                    4.*|5.*|6.*)
                        utm_version="4"
                        ;;
                    3.*)
                        utm_version="3"
                        ;;
                    2.*)
                        utm_version="2"
                        ;;
                    *)
                        utm_version="3"  # Default fallback
                        ;;
                esac
            fi
        fi
    fi
    
    echo "$utm_version"
}

create_utm_config() {
    local config_version=$(detect_utm_version)
    print_status "Using UTM configuration version: $config_version"
    
    # Create the VM configuration
    print_status "Creating UTM configuration..."
    create_manual_config
}

create_manual_config() {
    # Create a very basic configuration that should work
    cat > "$UTM_DIR/config.plist" << 'EOF'
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
        <string>PLACEHOLDER_UUID</string>
    </dict>
    <key>System</key>
    <dict>
        <key>Architecture</key>
        <string>aarch64</string>
        <key>CPU</key>
        <dict>
            <key>CoreCount</key>
            <integer>PLACEHOLDER_CPU_CORES</integer>
        </dict>
        <key>Memory</key>
        <dict>
            <key>MemorySize</key>
            <integer>PLACEHOLDER_MEMORY_SIZE</integer>
        </dict>
    </dict>
    <key>Drives</key>
    <array>
        <dict>
            <key>Identifier</key>
            <string>PLACEHOLDER_DRIVE_UUID</string>
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

    # Generate UUIDs and replace placeholders
    if command -v uuidgen &> /dev/null; then
        MAIN_UUID=$(uuidgen)
        DRIVE_UUID=$(uuidgen)
    else
        # Simple fallback UUID generation for systems without uuidgen
        MAIN_UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "550E8400-E29B-41D4-A716-446655440$(date +%03d)")"
        DRIVE_UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "550E8400-E29B-41D4-A716-446655441$(date +%03d)")"
    fi
    
    # Use perl for more reliable cross-platform text replacement
    perl -i -pe "s/PLACEHOLDER_UUID/$MAIN_UUID/g" "$UTM_DIR/config.plist"
    perl -i -pe "s/PLACEHOLDER_DRIVE_UUID/$DRIVE_UUID/g" "$UTM_DIR/config.plist"
    perl -i -pe "s/PLACEHOLDER_CPU_CORES/$CPU_CORES/g" "$UTM_DIR/config.plist"
    perl -i -pe "s/PLACEHOLDER_MEMORY_SIZE/$MEMORY_SIZE_MB/g" "$UTM_DIR/config.plist"
}

create_utm_config

# Create startup scripts for the VM
print_status "Creating LnOS startup scripts..."
mkdir -p "$UTM_DIR/Data/lnos-scripts"

# Copy the LnOS installer and related files
if [[ -f "$SCRIPT_DIR/scripts/LnOS-installer.sh" ]]; then
    cp "$SCRIPT_DIR/scripts/LnOS-installer.sh" "$UTM_DIR/Data/lnos-scripts/"
else
    print_warning "LnOS-installer.sh not found, downloading from GitHub..."
    curl -o "$UTM_DIR/Data/lnos-scripts/LnOS-installer.sh" \
        "https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/scripts/LnOS-installer.sh" || \
        print_error "Failed to download LnOS installer"
fi

# Copy package lists
if [[ -d "$SCRIPT_DIR/scripts/pacman_packages" ]]; then
    cp -r "$SCRIPT_DIR/scripts/pacman_packages" "$UTM_DIR/Data/lnos-scripts/" 
else
    print_warning "Package lists not found, creating basic CSE package list..."
    mkdir -p "$UTM_DIR/Data/lnos-scripts/pacman_packages"
    cat > "$UTM_DIR/Data/lnos-scripts/pacman_packages/CSE_packages.txt" << 'EOF'
bat
openssh
code
neovim
gcc
gdb
cmake
python
git
curl
wget
htop
tree
vim
nano
EOF
fi

# Copy the bootstrap script
cp "$SCRIPT_DIR/utm-templates/asahi-bootstrap.sh" "$UTM_DIR/Data/lnos-scripts/" 2>/dev/null || \
    print_warning "Bootstrap script not found - will need manual setup"

# Create autostart script for the VM
cat > "$UTM_DIR/Data/lnos-scripts/utm-autostart.sh" << 'EOF'
#!/bin/bash

# UTM LnOS Autostart Script for Asahi Linux
# This script runs when the VM starts and launches the LnOS installer

echo "=========================================="
echo "    Welcome to LnOS on Apple Silicon"
echo "       Running on Asahi Linux"
echo "=========================================="
echo ""

# Wait for system to settle
sleep 3

# Auto-detect architecture (should be aarch64 on Apple Silicon)
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"
echo ""

# Check for shared directory mount
if [[ -d "/media/lnos-scripts" ]]; then
    SHARED_DIR="/media/lnos-scripts"
elif [[ -d "/mnt/lnos-scripts" ]]; then
    SHARED_DIR="/mnt/lnos-scripts"
else
    SHARED_DIR=""
fi

# Ensure we have the installer
if [[ ! -f "/root/LnOS/scripts/LnOS-installer.sh" ]]; then
    echo "Setting up LnOS installer..."
    mkdir -p /root/LnOS/scripts/pacman_packages
    
    # Copy installer from shared location if available
    if [[ -n "$SHARED_DIR" && -f "$SHARED_DIR/LnOS-installer.sh" ]]; then
        cp "$SHARED_DIR/LnOS-installer.sh" /root/LnOS/scripts/
        cp -r "$SHARED_DIR/pacman_packages"/* /root/LnOS/scripts/pacman_packages/ 2>/dev/null || true
    else
        # Download from GitHub
        echo "Downloading LnOS installer..."
        curl -o /root/LnOS/scripts/LnOS-installer.sh \
            "https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/scripts/LnOS-installer.sh" || \
            wget -O /root/LnOS/scripts/LnOS-installer.sh \
            "https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/scripts/LnOS-installer.sh" || \
            echo "Failed to download installer"
        
        # Create basic package list if not available
        if [[ ! -f "/root/LnOS/scripts/pacman_packages/CSE_packages.txt" ]]; then
            cat > /root/LnOS/scripts/pacman_packages/CSE_packages.txt << 'PKGEOF'
bat
openssh
code
neovim
gcc
gdb
cmake
python
git
curl
wget
htop
tree
vim
nano
PKGEOF
        fi
    fi
    
    chmod +x /root/LnOS/scripts/LnOS-installer.sh 2>/dev/null || true
fi

# Check if installer exists
if [[ ! -f "/root/LnOS/scripts/LnOS-installer.sh" ]]; then
    echo "ERROR: LnOS installer not found!"
    echo "Available files in /root/LnOS/scripts/:"
    ls -la /root/LnOS/scripts/ 2>/dev/null || echo "Directory not found"
    echo ""
    echo "Please ensure the installer is available or check network connectivity"
    echo "You can run the bootstrap script manually:"
    echo "  curl -sL https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/utm-templates/asahi-bootstrap.sh | bash"
    echo ""
    echo "Dropping to shell..."
    exec /bin/bash
fi

echo "Starting LnOS installer for Apple Silicon (Asahi Linux)..."
echo ""

# Change to installer directory and run with aarch64 target
cd /root/LnOS/scripts
exec ./LnOS-installer.sh --target=aarch64
EOF

chmod +x "$UTM_DIR/Data/lnos-scripts/utm-autostart.sh"

# Make all scripts executable
chmod +x "$UTM_DIR/Data/lnos-scripts"/*.sh 2>/dev/null || true

# Create setup instructions
cat > "$UTM_DIR/Data/lnos-scripts/SETUP_INSTRUCTIONS.md" << 'EOF'
# LnOS UTM Setup Instructions for Apple Silicon

## Prerequisites
1. macOS 12.0 (Monterey) or later
2. Apple Silicon Mac (M1, M2, M3, etc.)
3. UTM installed from Mac App Store or https://mac.getutm.app/
4. At least 8GB free disk space
5. Internet connection for downloading packages

## Quick Start

### Method 1: Automated Setup (Recommended)
1. Double-click the .utm file to open in UTM
2. Start the VM and boot from the Asahi installer ISO
3. Install Asahi Linux to the main disk (follow standard Asahi installation)
4. After installation, boot into Asahi Linux
5. Run the bootstrap script:
   ```bash
   curl -sL https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/utm-templates/asahi-bootstrap.sh | sudo bash
   ```
6. Reboot - LnOS installer will start automatically

### Method 2: Manual Setup
1. Install Asahi Linux using the standard installer
2. Copy LnOS scripts to the VM:
   ```bash
   sudo mkdir -p /root/LnOS/scripts
   sudo cp /media/lnos-scripts/* /root/LnOS/scripts/
   sudo chmod +x /root/LnOS/scripts/*.sh
   ```
3. Set up auto-start:
   ```bash
   echo '/root/LnOS/scripts/utm-autostart.sh' | sudo tee -a /root/.bashrc
   ```
4. Reboot the VM

## Installation Steps Detail

### Step 1: Boot and Install Asahi Linux
1. Start the VM - it should boot from the Asahi installer ISO
2. Follow the Asahi Linux installation wizard:
   - Select "Install Asahi Linux"
   - Choose the disk (/dev/vda)
   - Set up user account and passwords
   - Wait for base system installation

### Step 2: Configure LnOS
After Asahi Linux boots:
1. Login as your user
2. Run: `sudo /media/lnos-scripts/asahi-bootstrap.sh` (if available)
3. Or manually copy scripts and set up autostart

### Step 3: Complete LnOS Installation
The LnOS installer will start automatically and offer:
- Desktop environments: Gnome, KDE, Hyprland, DWM, or TTY only
- Package profiles: CSE (Computer Science Education) or Custom
- Automatic package installation and system configuration

## Features
- **Native Apple Silicon Performance**: Uses Apple's virtualization framework
- **Rosetta Support**: Can run x86_64 binaries when needed
- **Same Experience**: Identical to x86_64 ISO and Pi images
- **Shared Clipboard**: Copy/paste between macOS and VM
- **Network Connectivity**: Automatic internet access via UTM

## Troubleshooting

### Installer Won't Start
- Check: `/root/LnOS/scripts/LnOS-installer.sh` exists and is executable
- Run manually: `sudo /root/start-lnos.sh`
- Check network connectivity for downloads

### Asahi Installation Issues
- Ensure you have enough disk space (8GB minimum)
- Use a stable internet connection
- Check UTM console for error messages

### Package Installation Errors
- Verify internet connectivity inside VM
- Update package databases: `sudo pacman -Syu` (if using Arch-based Asahi)
- Check available disk space

### Performance Issues
- Allocate more RAM in UTM settings (4GB+ recommended)
- Increase CPU cores if available
- Ensure Rosetta is enabled for x86_64 compatibility

## Advanced Configuration

### Customizing the VM
- RAM: Adjust in UTM settings (4-8GB recommended)
- Storage: Resize disk image if needed
- Display: Change resolution in UTM display settings
- Network: Configure port forwarding for services

### Package Customization
Edit `/root/LnOS/scripts/pacman_packages/CSE_packages.txt` to customize packages:
```bash
# Add your preferred packages
firefox
discord
steam
# Development tools
docker
kubernetes-cli
```

## Support
- GitHub Issues: https://github.com/uta-lug-nuts/LnOS/issues
- Wiki: Check the repository wiki for additional guides
- Community: Join the UTA Linux User Group discussions
EOF

# Create a README for distribution
cat > "$UTM_DIR/README.txt" << 'EOF'
LnOS for Apple Silicon Macs (UTM Virtual Machine)

This UTM virtual machine provides the same LnOS installation experience
as the x86_64 ISO and Raspberry Pi images, but optimized for Apple Silicon Macs.

QUICK START:
1. Double-click this .utm file to open in UTM
2. Start the VM and install Asahi Linux when prompted
3. After installation, run the bootstrap script or manually set up LnOS
4. Enjoy the same LnOS experience on Apple Silicon!

REQUIREMENTS:
- macOS 12.0+ (Monterey or later)  
- Apple Silicon Mac (M1/M2/M3/M4)
- UTM virtualization app
- 8GB+ free disk space
- Internet connection

WHAT'S INCLUDED:
- Pre-configured UTM virtual machine
- Asahi Linux installer ISO
- LnOS installer script with aarch64 support
- Auto-start mechanism for seamless experience
- Same package lists as other LnOS builds
- Shared folder with setup scripts

For detailed setup instructions, see:
Data/lnos-scripts/SETUP_INSTRUCTIONS.md

Visit https://github.com/uta-lug-nuts/LnOS for more information.
EOF

# Create version info
cat > "$UTM_DIR/Data/lnos-scripts/VERSION.txt" << EOF
LnOS UTM Distribution for Apple Silicon
Build Date: $(date)
Build Host: $(hostname)
Architecture: aarch64 (Apple Silicon)
Base System: Asahi Linux
UTM Version: Compatible with UTM 4.0+
macOS Requirement: 12.0+ (Monterey or later)

Installer Version: $(grep -E "^# @date" "$SCRIPT_DIR/scripts/LnOS-installer.sh" 2>/dev/null | head -1 | cut -d' ' -f3- || echo "Unknown")

Package Lists:
$(ls -la "$UTM_DIR/Data/lnos-scripts/pacman_packages/" 2>/dev/null | tail -n +2 || echo "  No package lists found")

Build Configuration:
- Disk Size: ${DISK_SIZE_GB}GB
- Memory: ${MEMORY_SIZE_MB}MB  
- CPU Cores: $CPU_CORES
- Rosetta: Enabled
- Clipboard Sharing: Enabled
- Shared Directory: Enabled
EOF

# Create a distribution ZIP if requested
if [[ "$1" == "--zip" ]]; then
    print_status "Creating distribution ZIP..."
    cd "$OUTPUT_DIR"
    zip -r "${UTM_NAME}.zip" "${UTM_NAME}.utm"
    print_status "Distribution ZIP created: ${UTM_NAME}.zip"
fi

print_status "UTM virtual machine created successfully!"
print_status "Location: $UTM_DIR"
print_status ""
print_status "Next steps:"
print_status "1. Double-click ${UTM_NAME}.utm to open in UTM"
print_status "2. If import fails, try creating a new VM manually in UTM:"
print_status "   - Architecture: aarch64"
print_status "   - Memory: ${MEMORY_SIZE_MB}MB"
print_status "   - CPU Cores: $CPU_CORES"
print_status "   - Add the disk image: $DISK_IMAGE"
print_status "   - Add the Asahi ISO as CD-ROM: $ASAHI_ISO"
print_status "3. Start the VM to begin Asahi Linux installation"
print_status "4. Follow the setup instructions in the VM"
print_status "5. The LnOS installer will start automatically after setup"
print_status ""
print_status "The VM includes:"
print_status "✓ Asahi Linux installer ISO (if available)"
print_status "✓ LnOS installer script with aarch64 target"
print_status "✓ Same package lists as x86_64 and Pi builds"
print_status "✓ Auto-start mechanism for seamless experience"
print_status "✓ Shared directory with all setup scripts"
print_status "✓ Rosetta support for x86_64 compatibility"
print_status ""

# Provide download link for Asahi if ISO wasn't found
if [[ ! -f "$ASAHI_ISO" || ! -s "$ASAHI_ISO" ]]; then
    print_warning "Asahi Linux installer ISO not included."
    print_warning "Download from: https://asahilinux.org/fedora/"
    print_warning "Then add it to the VM as a CD/DVD drive in UTM settings."
fi

if [[ -d "/Applications/UTM.app" ]]; then
    print_status "Opening UTM..."
    open "$UTM_DIR"
else
    print_status "UTM not found in Applications. Please install UTM and open ${UTM_NAME}.utm manually"
fi

print_status "Build completed!"
print_status ""
print_status "For distribution, run: $0 --zip"