#!/bin/bash

# CI-Compatible UTM Build Script for LnOS
# This script builds and validates UTM VMs for CI/CD pipelines

set -e

# Colors for output (disabled in CI)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

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
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/out"
UTM_NAME="lnos-asahi-$(date +%Y.%m.%d)"
UTM_DIR="$OUTPUT_DIR/${UTM_NAME}.utm"
DISK_SIZE_GB="20"
MEMORY_SIZE_MB="4096"
CPU_CORES="4"

# CI Environment detection
CI_ENV=${CI:-false}
GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}

print_status "LnOS UTM CI Build Script"
print_status "========================="
print_status "CI Environment: $CI_ENV"
print_status "GitHub Actions: $GITHUB_ACTIONS"
print_status ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed to run on macOS only"
    exit 1
fi

# Check if UTM is installed (skip in CI if not available)
if ! command -v utmctl &> /dev/null && [[ ! -d "/Applications/UTM.app" ]]; then
    if [[ "$CI_ENV" == "true" ]]; then
        print_warning "UTM not installed in CI environment. Creating artifacts only."
        UTM_AVAILABLE=false
    else
        print_error "UTM is not installed. Please install UTM first."
        exit 1
    fi
else
    UTM_AVAILABLE=true
fi

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
    print_status "Disk image created successfully"
else
    print_warning "qemu-img not found, creating placeholder disk image"
    # Create a minimal placeholder - UTM will create the actual disk
    touch "$DISK_IMAGE"
fi

# Download Asahi Linux installer
print_status "Downloading Asahi Linux installer ISO..."
ASAHI_ISO="$UTM_DIR/Images/asahi-installer.iso"
ASAHI_DOWNLOAD_URL="https://cdn.asahilinux.org/os/installer/latest/asahi-installer.iso"

if curl -L -o "$ASAHI_ISO" "$ASAHI_DOWNLOAD_URL"; then
    print_status "Successfully downloaded Asahi Linux installer ISO!"
    # Verify the download
    if [[ -s "$ASAHI_ISO" ]]; then
        print_status "ISO file size: $(du -h "$ASAHI_ISO" | cut -f1)"
    else
        print_error "Downloaded ISO file is empty"
        exit 1
    fi
else
    print_error "Failed to download Asahi installer ISO"
    exit 1
fi

# Create CI-compatible UTM configuration
print_status "Creating CI-compatible UTM configuration..."
create_ci_config() {
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
        # Simple fallback UUID generation
        MAIN_UUID="550E8400-E29B-41D4-A716-446655440$(date +%03d)"
        DRIVE_UUID="550E8400-E29B-41D4-A716-446655441$(date +%03d)"
    fi
    
    # Use perl for more reliable cross-platform text replacement
    perl -i -pe "s/PLACEHOLDER_UUID/$MAIN_UUID/g" "$UTM_DIR/config.plist"
    perl -i -pe "s/PLACEHOLDER_DRIVE_UUID/$DRIVE_UUID/g" "$UTM_DIR/config.plist"
    perl -i -pe "s/PLACEHOLDER_CPU_CORES/$CPU_CORES/g" "$UTM_DIR/config.plist"
    perl -i -pe "s/PLACEHOLDER_MEMORY_SIZE/$MEMORY_SIZE_MB/g" "$UTM_DIR/config.plist"
}

create_ci_config

# Create CI artifacts
print_status "Creating CI artifacts..."

# Create startup scripts for the VM
mkdir -p "$UTM_DIR/Data/lnos-scripts"

# Copy the LnOS installer and related files
if [[ -f "$PROJECT_DIR/scripts/LnOS-installer.sh" ]]; then
    cp "$PROJECT_DIR/scripts/LnOS-installer.sh" "$UTM_DIR/Data/lnos-scripts/"
else
    print_warning "LnOS-installer.sh not found, downloading from GitHub..."
    curl -o "$UTM_DIR/Data/lnos-scripts/LnOS-installer.sh" \
        "https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/scripts/LnOS-installer.sh" || \
        print_error "Failed to download LnOS installer"
fi

# Copy package lists
if [[ -d "$PROJECT_DIR/scripts/pacman_packages" ]]; then
    cp -r "$PROJECT_DIR/scripts/pacman_packages" "$UTM_DIR/Data/lnos-scripts/" 
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

# Create CI validation script
cat > "$UTM_DIR/Data/lnos-scripts/ci-validation.sh" << 'EOF'
#!/bin/bash

# CI Validation Script for LnOS UTM VM
# This script validates the VM setup in CI environments

set -e

echo "=== LnOS UTM CI Validation ==="
echo "Timestamp: $(date)"
echo "Host: $(hostname)"
echo "Architecture: $(uname -m)"
echo ""

# Check if we're in a VM
if [[ -f "/proc/cpuinfo" ]]; then
    echo "CPU Info:"
    grep -E "model name|Hardware" /proc/cpuinfo | head -1
fi

# Check disk space
echo ""
echo "Disk Usage:"
df -h /

# Check memory
echo ""
echo "Memory Usage:"
free -h 2>/dev/null || echo "Memory info not available"

# Check network connectivity
echo ""
echo "Network Connectivity:"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ Internet connectivity: OK"
else
    echo "✗ Internet connectivity: FAILED"
fi

# Check for LnOS installer
echo ""
echo "LnOS Installer Check:"
if [[ -f "/root/LnOS/scripts/LnOS-installer.sh" ]]; then
    echo "✓ LnOS installer found"
    chmod +x /root/LnOS/scripts/LnOS-installer.sh
else
    echo "✗ LnOS installer not found"
fi

# Check package lists
echo ""
echo "Package Lists Check:"
if [[ -d "/root/LnOS/scripts/pacman_packages" ]]; then
    echo "✓ Package lists directory found"
    ls -la /root/LnOS/scripts/pacman_packages/
else
    echo "✗ Package lists directory not found"
fi

echo ""
echo "=== CI Validation Complete ==="
EOF

chmod +x "$UTM_DIR/Data/lnos-scripts/ci-validation.sh"

# Create CI metadata
cat > "$UTM_DIR/Data/ci-metadata.json" << EOF
{
    "build_info": {
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "hostname": "$(hostname)",
        "architecture": "$(uname -m)",
        "os": "$(uname -s)",
        "ci_environment": "$CI_ENV",
        "github_actions": "$GITHUB_ACTIONS"
    },
    "vm_config": {
        "name": "LnOS Asahi Linux",
        "architecture": "aarch64",
        "memory_mb": $MEMORY_SIZE_MB,
        "cpu_cores": $CPU_CORES,
        "disk_size_gb": $DISK_SIZE_GB,
        "utm_version": "1"
    },
    "artifacts": {
        "disk_image": "Images/disk0.qcow2",
        "asahi_iso": "Images/asahi-installer.iso",
        "lnos_scripts": "Data/lnos-scripts/",
        "validation_script": "Data/lnos-scripts/ci-validation.sh"
    }
}
EOF

# Create distribution ZIP for CI artifacts
print_status "Creating CI distribution package..."
cd "$OUTPUT_DIR"
zip -r "${UTM_NAME}-ci.zip" "${UTM_NAME}.utm"
print_status "CI distribution package created: ${UTM_NAME}-ci.zip"

# Validate the build
print_status "Validating build artifacts..."
if [[ -f "$UTM_DIR/config.plist" ]]; then
    print_status "✓ UTM configuration created"
else
    print_error "✗ UTM configuration missing"
    exit 1
fi

if [[ -f "$DISK_IMAGE" ]]; then
    print_status "✓ Disk image created"
else
    print_error "✗ Disk image missing"
    exit 1
fi

if [[ -f "$ASAHI_ISO" && -s "$ASAHI_ISO" ]]; then
    print_status "✓ Asahi installer ISO downloaded"
else
    print_error "✗ Asahi installer ISO missing or empty"
    exit 1
fi

if [[ -f "$UTM_DIR/Data/lnos-scripts/LnOS-installer.sh" ]]; then
    print_status "✓ LnOS installer script included"
else
    print_error "✗ LnOS installer script missing"
    exit 1
fi

# CI-specific output
if [[ "$CI_ENV" == "true" ]]; then
    print_status "CI Build Summary:"
    print_status "=================="
    print_status "Build Directory: $UTM_DIR"
    print_status "Distribution ZIP: $OUTPUT_DIR/${UTM_NAME}-ci.zip"
    print_status "Disk Image: $DISK_IMAGE"
    print_status "Asahi ISO: $ASAHI_ISO"
    print_status "Configuration: $UTM_DIR/config.plist"
    print_status ""
    
    # Set CI output variables
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "::set-output name=utm_bundle::$UTM_DIR"
        echo "::set-output name=distribution_zip::$OUTPUT_DIR/${UTM_NAME}-ci.zip"
        echo "::set-output name=disk_image::$DISK_IMAGE"
        echo "::set-output name=asahi_iso::$ASAHI_ISO"
    fi
    
    print_status "CI build completed successfully!"
else
    print_status "Local build completed successfully!"
    print_status "Location: $UTM_DIR"
    print_status "Distribution ZIP: $OUTPUT_DIR/${UTM_NAME}-ci.zip"
fi

print_status ""
print_status "Build artifacts ready for deployment!" 