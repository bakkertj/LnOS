#!/bin/bash

# LnOS Asahi Linux Bootstrap Script
# This script runs inside the Asahi Linux VM to set up LnOS installer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Setting up LnOS on Asahi Linux..."

# Detect if we're running on Apple Silicon
if [[ "$(uname -m)" != "aarch64" ]]; then
    print_error "This script requires Apple Silicon (aarch64) architecture"
    exit 1
fi

# Update system packages
print_status "Updating system packages..."
if command -v pacman &> /dev/null; then
    # Arch-based Asahi
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm gum base-devel git wget curl
elif command -v dnf &> /dev/null; then
    # Fedora-based Asahi
    sudo dnf update -y
    sudo dnf install -y git wget curl gcc make
    
    # Install gum for Fedora
    print_status "Installing gum for pretty interfaces..."
    wget -O /tmp/gum.rpm "https://github.com/charmbracelet/gum/releases/latest/download/gum-0.14.5-1.aarch64.rpm" || true
    sudo rpm -i /tmp/gum.rpm 2>/dev/null || true
elif command -v apt &> /dev/null; then
    # Debian-based systems
    sudo apt update
    sudo apt install -y git wget curl build-essential
    
    # Install gum for Debian/Ubuntu
    print_status "Installing gum for pretty interfaces..."
    wget -O /tmp/gum.deb "https://github.com/charmbracelet/gum/releases/latest/download/gum_0.14.5_arm64.deb" || true
    sudo dpkg -i /tmp/gum.deb 2>/dev/null || true
    sudo apt-get install -f -y 2>/dev/null || true
fi

# Set up LnOS directory structure
print_status "Setting up LnOS directory structure..."
sudo mkdir -p /root/LnOS/scripts/pacman_packages

# Copy LnOS installer if available from mounted share
if [[ -d "/mnt/lnos-scripts" ]]; then
    print_status "Copying LnOS installer from UTM share..."
    sudo cp /mnt/lnos-scripts/LnOS-installer.sh /root/LnOS/scripts/ 2>/dev/null || true
    sudo cp -r /mnt/lnos-scripts/pacman_packages/* /root/LnOS/scripts/pacman_packages/ 2>/dev/null || true
fi

# Download LnOS installer if not available
if [[ ! -f "/root/LnOS/scripts/LnOS-installer.sh" ]]; then
    print_status "Downloading LnOS installer from GitHub..."
    sudo wget -O /root/LnOS/scripts/LnOS-installer.sh \
        "https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/scripts/LnOS-installer.sh" || \
    print_warning "Failed to download installer - please install manually"
fi

# Make installer executable
sudo chmod +x /root/LnOS/scripts/LnOS-installer.sh 2>/dev/null || true

# Create Asahi-specific package list
print_status "Creating Asahi Linux package list..."
cat << 'EOF' | sudo tee /root/LnOS/scripts/pacman_packages/CSE_packages.txt > /dev/null
# CSE packages for Asahi Linux (Apple Silicon)
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

# Create auto-start mechanism
print_status "Setting up auto-start mechanism..."

# For systemd-based systems
if command -v systemctl &> /dev/null; then
    sudo tee /etc/systemd/system/lnos-autostart.service > /dev/null << 'EOF'
[Unit]
Description=LnOS Auto-start
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/root/LnOS/scripts/LnOS-installer.sh --target=aarch64
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    sudo systemctl enable lnos-autostart.service
fi

# Add to root's bashrc as backup
print_status "Adding to root bashrc as backup..."
if ! grep -q "LnOS-installer" /root/.bashrc 2>/dev/null; then
    echo "" | sudo tee -a /root/.bashrc > /dev/null
    echo "# LnOS Auto-start" | sudo tee -a /root/.bashrc > /dev/null
    echo 'if [[ $(tty) == "/dev/tty1" ]] && [[ ! -f /tmp/lnos-autostart-run ]]; then' | sudo tee -a /root/.bashrc > /dev/null
    echo '    touch /tmp/lnos-autostart-run' | sudo tee -a /root/.bashrc > /dev/null
    echo '    echo "Starting LnOS installer..."' | sudo tee -a /root/.bashrc > /dev/null
    echo '    cd /root/LnOS/scripts' | sudo tee -a /root/.bashrc > /dev/null
    echo '    ./LnOS-installer.sh --target=aarch64' | sudo tee -a /root/.bashrc > /dev/null
    echo 'fi' | sudo tee -a /root/.bashrc > /dev/null
fi

# Create a manual startup script
cat << 'EOF' | sudo tee /root/start-lnos.sh > /dev/null
#!/bin/bash
echo "Starting LnOS installer for Apple Silicon..."
cd /root/LnOS/scripts
./LnOS-installer.sh --target=aarch64
EOF

sudo chmod +x /root/start-lnos.sh

print_status "LnOS setup completed!"
print_status "The installer will start automatically on next boot."
print_status "Or run manually with: sudo /root/start-lnos.sh"
print_status ""
print_status "Rebooting in 10 seconds..."
sleep 10
sudo reboot