# User Package Management Guide

## Overview

Calculinux separates system software (managed by RAUC updates) from user-installed software (managed by opkg). User packages install to `/usr/local` and persist across system updates.

## Installing Packages

```bash
# Update package lists
opkg update

# Install a package
opkg install vim

# Search for packages
opkg find '*python*'

# List installed packages
opkg list-installed
```

Packages are installed to `/usr/local` which survives system updates.

## System Updates

When you apply a RAUC system update:

### Minor Updates (e.g., 5.2.3 → 5.2.4)
1. **Automatic**: System checks and upgrades only incompatible packages
2. **No user action needed**: Usually seamless

### Major Updates (e.g., Scarthgap → Walnascar)
1. **Before installation**: You'll see a warning message:
   ```
   MAJOR VERSION UPGRADE DETECTED
   
   User-installed packages detected: X package(s)
   All packages will be automatically reinstalled
   
   IMPORTANT: Ensure network connectivity!
   
   Estimated download size: ~X MB
   ```
2. **Network required**: Connect to WiFi/Ethernet before proceeding
3. **Cancellation option**: Press Ctrl+C within 10 seconds to cancel
4. **Automatic reinstall**: After reboot, all packages reinstall automatically

### After Any Update
- **Verification**: Run `calculinux-upgrade-check` to verify
- **Manual upgrade** (if needed): `calculinux-upgrade-check --upgrade`

### Version Compatibility

- **Minor updates** (5.2.3 → 5.2.4): Usually seamless, automatic
- **Major updates** (Scarthgap → Walnascar): 
  - Pre-install warning displayed
  - Network connectivity required
  - All packages automatically reinstalled
  - ~1MB download per installed package

## Package Removal

### Remove Packages
```bash
opkg remove package-name
```

### Check Package Info
```bash
opkg info package-name
opkg files package-name
```

### Hold Packages (Prevent Upgrades)
```bash
opkg flag hold package-name   # Hold
opkg flag ok package-name     # Release hold
```

## Package Feeds

Feeds are configured in `/etc/opkg/opkg.conf`:
```
src/gz all https://opkg.calculinux.org/ipk/scarthgap/all
src/gz luckfox-lyra https://opkg.calculinux.org/ipk/scarthgap/luckfox-lyra
src/gz any https://opkg.calculinux.org/ipk/scarthgap/any
src/gz noarch https://opkg.calculinux.org/ipk/scarthgap/noarch
```

Feed URLs are version-specific and update automatically during major system upgrades.

## Troubleshooting

### Package Won't Run After Update
```bash
# Check and upgrade
calculinux-upgrade-check --upgrade

# Or manually reinstall
opkg remove package-name
opkg install package-name
```

### Check Library Dependencies
```bash
ldd /usr/local/bin/binary-name
```

### Storage Issues
```bash
# Check space
df -h /data

# Clean package cache
rm -rf /var/lib/opkg/lists/*
opkg update
```

## Examples

### Development Tools
```bash
opkg install python3 git vim make
```

### Web Server
```bash
opkg install nginx
systemctl enable --now nginx
```

### Utilities
```bash
opkg install tmux htop curl
```

## Advanced

### Local Package Installation
```bash
opkg install /path/to/package.ipk
```

### Manual Software in /opt
The `/opt` directory is writable and persistent for manually-managed software:
```bash
# Example: Installing custom software
cd /opt
wget https://example.com/software.tar.gz
tar xzf software.tar.gz
# Add /opt/software/bin to your PATH if needed
```

Note: Use opkg for package management when possible. `/opt` is for software not available as packages.

### Configuration Files
- **Read-only**: Original package configs
- **Writable**: Your modifications (in `/data` overlay)
- Reinstalling packages preserves your changes

## Getting Help

- Check package status: `calculinux-upgrade-check`
- View logs: `journalctl -xe`
- Check dependencies: `ldd /usr/local/bin/binary-name`
- RAUC logs: `journalctl -t rauc-post-install`

For technical details, see [Architecture Documentation](opkg-readonly-rootfs-strategy.md).
