# LnOS - Custom Arch Linux Installer

A custom Arch Linux distribution with automated installation for **x86_64**, **Raspberry Pi (aarch64)**, and **Apple Silicon Macs (UTM)**.

## Supported Platforms

### 🖥️ x86_64 Desktop/Laptop
- **ISO Image**: Bootable ISO for physical machines and VMs
- **Build**: `./build-iso.sh`
- **Use Case**: Desktop computers, laptops, standard VMs

### 🍓 Raspberry Pi (ARM64)
- **SD Card Image**: Ready-to-flash `.img` files  
- **Build**: `./build-arm-image.sh`
- **Use Case**: Pi 4, Pi 5, ARM development boards

### 🍎 Apple Silicon Macs (NEW)
- **UTM Virtual Machine**: `.utm` bundle for macOS
- **Build**: `./build-utm-asahi.sh` (requires macOS)
- **Use Case**: M1/M2/M3/M4 Macs with UTM virtualization

## Quick Start

### For Students & End Users

**x86_64 (Desktop/Laptop)**:
1. Download the latest ISO from releases
2. Flash to USB stick or boot in VM
3. Follow the installer prompts

**Raspberry Pi**:
1. Download the Pi image from releases
2. Flash to SD card with dd/Etcher
3. Boot Pi and run the installer

**Apple Silicon Mac** ⭐ **NEW**:
1. Install [UTM](https://mac.getutm.app/) on your Mac
2. Download the `.utm` bundle from releases
3. Double-click to open in UTM
4. Start VM and follow setup instructions

### For Developers

```bash
# Clone repository
git clone https://github.com/uta-lug-nuts/LnOS.git
cd LnOS

# Build for your target platform
./build-iso.sh           # x86_64 ISO
./build-arm-image.sh     # Raspberry Pi image  
./build-utm-asahi.sh     # Apple Silicon UTM (macOS only)
```

## Features

All platforms provide the same LnOS experience:

- **Consistent Interface**: Same installer UI across all architectures
- **Desktop Environments**: Gnome, KDE, Hyprland, DWM, or TTY-only
- **Package Profiles**: CSE (Computer Science Education) or Custom
- **Auto-configuration**: Network, SSH, development tools
- **Same Packages**: Identical software availability across platforms

### Apple Silicon Specific Features
- **Native Performance**: Uses Apple Virtualization Framework
- **Rosetta Support**: Run x86_64 binaries when needed
- **macOS Integration**: Shared clipboard, folders
- **Easy Distribution**: Single `.utm` file to share

## Architecture Support

| Platform | Architecture | Base System | Package Manager |
|----------|-------------|-------------|-----------------|
| Desktop/Laptop | x86_64 | Arch Linux | pacman |
| Raspberry Pi | aarch64 | Arch Linux ARM | pacman |
| Apple Silicon | aarch64 | Asahi Linux | pacman |

All platforms use the same `LnOS-installer.sh` script with architecture detection.

## Installation Comparison

| Method | Setup Time | Requirements | Use Case |
|--------|------------|--------------|----------|
| **x86_64 ISO** | ~30 min | USB stick or VM | Physical machines, standard VMs |
| **Pi Image** | ~45 min | SD card, Pi hardware | ARM development, IoT projects |
| **UTM Mac** | ~20 min | macOS 12.0+, UTM app | Mac development, testing |

## Getting Started

### Documentation
- **General**: [Main Documentation](docs/)
- **x86_64**: [ISO Build Guide](docs/iso-build-readme.md)
- **Raspberry Pi**: [ARM Build Guide](docs/arm-build-readme.md)
- **Apple Silicon**: [UTM Setup Guide](README-UTM.md) ⭐ **NEW**

### System Requirements

**All Platforms**:
- 8GB+ storage space
- Internet connection for packages
- 4GB+ RAM recommended

**Apple Silicon Specific**:
- macOS 12.0 (Monterey) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- UTM virtualization app

## Build Scripts

| Script | Platform | Output |
|--------|----------|---------|
| `build-iso.sh` | x86_64 | Bootable ISO image |
| `build-arm-image.sh` | Raspberry Pi | SD card image |
| `build-utm-asahi.sh` | Apple Silicon | UTM virtual machine |

## Development

Same codebase supports all three platforms:
- **Shared**: LnOS installer script, package lists, configurations
- **Platform-specific**: Boot mechanisms, base systems, virtualization

### Contributing
1. Test on your target platform(s)
2. Ensure installer works across architectures  
3. Update documentation for new features
4. Submit PR with platform testing results

## Support Matrix

| Feature | x86_64 | Pi (ARM64) | Apple Silicon |
|---------|--------|------------|---------------|
| Auto-installer | ✅ | ✅ | ✅ |
| Desktop environments | ✅ | ✅ | ✅ |
| Development tools | ✅ | ✅ | ✅ |
| Network auto-config | ✅ | ✅ | ✅ |
| SSH access | ✅ | ✅ | ✅ |
| Package profiles | ✅ | ✅ | ✅ |
| x86_64 compatibility | Native | Emulation | Rosetta |

## License

Apache License 2.0 - see [LICENSE](LICENSE) file.

## Community

- **Issues**: [GitHub Issues](https://github.com/uta-lug-nuts/LnOS/issues)
- **Discussions**: Repository discussions
- **University**: UTA Linux User Group

---

*LnOS now supports students with x86_64 PCs, Raspberry Pi SBCs, and Apple Silicon Macs - providing a consistent Linux development environment across all major platforms.*