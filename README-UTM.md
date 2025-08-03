# LnOS UTM Distribution for Apple Silicon Macs

This directory contains scripts and configurations to create a UTM virtual machine that runs the same LnOS installer as the x86_64 ISO and Raspberry Pi images, but optimized for Apple Silicon Macs using Asahi Linux.

## Overview

The UTM distribution provides:
- **Same Experience**: Identical LnOS installer interface and package selection
- **Apple Silicon Native**: Uses Apple's virtualization framework for optimal performance
- **Rosetta Support**: Can run x86_64 binaries when needed
- **Easy Distribution**: Double-click `.utm` file to run
- **Auto-start**: LnOS installer launches automatically after OS installation

## Prerequisites

- **macOS 12.0+** (Monterey or later)
- **Apple Silicon Mac** (M1, M2, M3, M4)
- **UTM** installed ([Mac App Store](https://apps.apple.com/app/utm-virtual-machines/id1538878817) or [direct download](https://mac.getutm.app/))
- **8GB+ free disk space**
- **Internet connection** for package downloads

## Quick Start

### For End Users (Download Pre-built VM)

1. Download the latest `lnos-asahi-YYYY.MM.DD.utm` file
2. Double-click to open in UTM
3. Start the VM and follow the installation prompts
4. LnOS installer will start automatically after OS installation

### For Developers (Build from Source)

```bash
# Clone the repository
git clone https://github.com/uta-lug-nuts/LnOS.git
cd LnOS

# Build the UTM virtual machine
./build-utm-asahi.sh

# Create distribution ZIP (optional)
./build-utm-asahi.sh --zip
```

## Build Process

The `build-utm-asahi.sh` script creates a complete UTM virtual machine bundle:

### What it Creates

```
lnos-asahi-YYYY.MM.DD.utm/
├── config.plist              # UTM configuration
├── Images/
│   ├── disk0.qcow2           # Main VM disk (20GB)
│   └── asahi-installer.iso   # Asahi Linux installer
├── Data/
│   └── lnos-scripts/
│       ├── LnOS-installer.sh         # Main installer script
│       ├── utm-autostart.sh          # Auto-start mechanism
│       ├── asahi-bootstrap.sh        # Asahi setup script
│       ├── pacman_packages/          # Package lists
│       ├── SETUP_INSTRUCTIONS.md    # Detailed setup guide
│       └── VERSION.txt               # Build information
└── README.txt                # Quick start guide
```

### UTM Configuration Features

- **Architecture**: aarch64 (Apple Silicon native)
- **Memory**: 4GB (configurable)
- **CPU**: 4 cores (configurable)
- **Storage**: 20GB expandable disk
- **Network**: Shared networking with internet access
- **Display**: VirtIO-GPU with 1280x1024 resolution
- **Clipboard**: Shared between macOS and VM
- **Rosetta**: Enabled for x86_64 compatibility
- **Shared Directory**: Scripts accessible from VM

## Installation Methods

### Method 1: Automated Setup (Recommended)

1. **Start VM**: Boot from Asahi installer ISO
2. **Install Asahi**: Follow standard Asahi Linux installation
3. **Run Bootstrap**: Execute the bootstrap script:
   ```bash
   curl -sL https://raw.githubusercontent.com/uta-lug-nuts/LnOS/main/utm-templates/asahi-bootstrap.sh | sudo bash
   ```
4. **Reboot**: LnOS installer starts automatically

### Method 2: Manual Setup

1. **Install Asahi Linux** using the included installer ISO
2. **Copy Scripts** from the shared directory:
   ```bash
   sudo mkdir -p /root/LnOS/scripts
   sudo cp /media/lnos-scripts/* /root/LnOS/scripts/
   sudo chmod +x /root/LnOS/scripts/*.sh
   ```
3. **Configure Auto-start**:
   ```bash
   echo '/root/LnOS/scripts/utm-autostart.sh' | sudo tee -a /root/.bashrc
   ```
4. **Reboot** the VM

## LnOS Installer Features

Once the installer starts, you get the same experience as other LnOS builds:

### Desktop Environment Options
- **Gnome** - Good for beginners, similar to macOS
- **KDE** - Good for beginners, similar to Windows  
- **Hyprland** - Tiling window manager with basic dotfiles
- **DWM** - Minimal tiling window manager
- **TTY** - Command line only

### Package Profiles
- **CSE** - Computer Science Education packages (development tools, editors, etc.)
- **Custom** - Manual package selection

### Included Packages (CSE Profile)
```
bat          # Better cat with syntax highlighting
openssh      # SSH client/server
code         # Visual Studio Code
neovim       # Modern vim editor
gcc          # GNU Compiler Collection
gdb          # GNU Debugger
cmake        # Build system
python       # Python programming language
git          # Version control
curl/wget    # Download tools
htop         # Process monitor
tree         # Directory tree viewer
vim/nano     # Text editors
```

## Technical Details

### Architecture Support
- **Primary**: aarch64 (Apple Silicon native)
- **Secondary**: x86_64 via Rosetta translation
- **Package Manager**: pacman (Arch Linux)
- **Base System**: Asahi Linux (Arch Linux for Apple Silicon)

### Performance Characteristics
- **Virtualization**: Apple Virtualization Framework (native)
- **Boot Time**: ~10-15 seconds after OS installation
- **Memory Usage**: ~1-2GB baseline (before desktop environment)
- **Storage**: Efficient qcow2 format, grows as needed

### Networking
- **Internet Access**: Automatic via UTM shared networking
- **SSH**: Enabled and configured
- **Package Downloads**: Direct from Arch repositories
- **Port Forwarding**: Configurable in UTM settings

## Customization

### Build-time Customization

Edit `build-utm-asahi.sh` to modify:
```bash
DISK_SIZE_GB="20"        # Increase for more storage
MEMORY_SIZE_MB="4096"    # Adjust RAM allocation
CPU_CORES="4"            # Change CPU core count
```

### Runtime Customization

After installation, modify:
- **Package Lists**: Edit `/root/LnOS/scripts/pacman_packages/CSE_packages.txt`
- **Auto-start**: Modify `/root/LnOS/scripts/utm-autostart.sh`
- **Display**: Adjust resolution in UTM settings
- **Resources**: Change RAM/CPU in UTM configuration

### Adding Custom Packages

Create additional package lists:
```bash
# Create custom package list
cat > /root/LnOS/scripts/pacman_packages/Custom_packages.txt << EOF
firefox
discord
steam
docker
kubernetes-cli
EOF
```

## Distribution

### Creating Distribution Files

```bash
# Build VM bundle
./build-utm-asahi.sh

# Create ZIP for distribution
./build-utm-asahi.sh --zip

# Upload to release or file sharing
mv out/lnos-asahi-*.zip /path/to/distribution/
```

### File Sizes
- **UTM Bundle**: ~2-4GB (depending on included ISO)
- **Compressed ZIP**: ~1-2GB
- **After Installation**: ~8-15GB (depending on packages)

## Troubleshooting

### Common Issues

#### UTM Won't Start VM
- **Check macOS Version**: Requires macOS 12.0+
- **Verify Apple Silicon**: Intel Macs need different approach
- **UTM Permissions**: Allow UTM in System Preferences

#### Installer Won't Start
- **Check Scripts**: Verify `/root/LnOS/scripts/LnOS-installer.sh` exists
- **Manual Start**: Run `sudo /root/start-lnos.sh`
- **Network**: Ensure internet connectivity for downloads

#### Package Installation Fails
- **Update Repos**: Run `sudo pacman -Syu`
- **Check Space**: Ensure adequate disk space
- **Mirrors**: Verify repository mirrors are accessible

#### Performance Issues
- **Increase RAM**: 4GB minimum, 8GB recommended
- **More Cores**: Allocate additional CPU cores
- **Rosetta**: Ensure enabled for x86_64 compatibility

### Debug Information

Check these locations for debugging:
- **UTM Logs**: Console.app → UTM processes
- **VM Logs**: `/tmp/*-debug.log` inside VM
- **Installer Logs**: Check installer output
- **Network**: `ip a` and `ping google.com` inside VM

## Differences from Other LnOS Builds

### vs. x86_64 ISO
- ✅ **Same**: Interface, packages, installer logic
- 🔄 **Different**: Base architecture (aarch64 vs x86_64)
- ➕ **Added**: Rosetta x86_64 compatibility
- ➕ **Added**: macOS integration (clipboard, shared folders)

### vs. Raspberry Pi Image
- ✅ **Same**: ARM64 architecture, package compatibility
- 🔄 **Different**: Asahi Linux vs. Arch Linux ARM
- ➕ **Added**: Virtualization benefits (snapshots, suspend/resume)
- ➕ **Added**: Better performance on Apple Silicon

### vs. Manual Installation
- ✅ **Same**: End result after installation
- ➕ **Added**: Pre-configured environment
- ➕ **Added**: Auto-start mechanism
- ➕ **Added**: Shared scripts and resources
- ⚡ **Faster**: No manual setup required

## Development

### Contributing

1. Fork the repository
2. Make changes to build scripts or configurations
3. Test with `./build-utm-asahi.sh`
4. Submit pull request with:
   - Description of changes
   - Testing performed
   - Screenshots if UI changes

### File Structure

```
LnOS/
├── build-utm-asahi.sh           # Main build script
├── utm-templates/
│   └── asahi-bootstrap.sh       # VM setup script
├── scripts/
│   ├── LnOS-installer.sh        # Main installer (shared)
│   └── pacman_packages/         # Package lists (shared)
├── README-UTM.md                # This documentation
└── out/                         # Build output directory
    └── lnos-asahi-YYYY.MM.DD.utm/  # Generated VM bundle
```

### Testing

```bash
# Build test VM
./build-utm-asahi.sh

# Test installation process
# 1. Open UTM bundle
# 2. Install Asahi Linux
# 3. Run bootstrap script
# 4. Verify LnOS installer starts
# 5. Test package installation
```

## License

Same as the main LnOS project - Apache License 2.0.

## Support

- **Issues**: [GitHub Issues](https://github.com/uta-lug-nuts/LnOS/issues)
- **Discussions**: Repository discussions
- **Wiki**: Check repository wiki for additional guides
- **Community**: UTA Linux User Group

---

*This UTM distribution enables the same LnOS experience on Apple Silicon Macs, providing a consistent development environment across x86_64, ARM64, and Apple Silicon architectures.*