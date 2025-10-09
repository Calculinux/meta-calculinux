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

# Remove a package
opkg remove vim
```

All packages automatically install to `/usr/local` which survives system updates.

## System Updates

### Minor Updates (e.g., 5.2.3 → 5.2.4)
- **Automatic**: System upgrades only incompatible packages
- **No user action needed**: Usually seamless

### Major Updates (e.g., Scarthgap → Walnascar)
1. **Before installation**: You'll see a warning with:
   - Number of packages that will be reinstalled
   - Network connectivity requirement
   - 10-second cancellation window (Ctrl+C to cancel)
2. **During upgrade**: Packages are downloaded
3. **After reboot**: Packages automatically reinstall on first boot
4. **Verification**: Run `calculinux-upgrade-check` to verify

### After Updates

Check package status:
```bash
calculinux-upgrade-check
```

If needed, manually upgrade packages:
```bash
calculinux-upgrade-check --upgrade
```
- **Manual upgrade** (if needed): `calculinux-upgrade-check --upgrade`

### Version Compatibility

- **Minor updates** (5.2.3 → 5.2.4): Usually seamless, automatic
- **Major updates** (Scarthgap → Walnascar): 
Check package status:
```bash
calculinux-upgrade-check
```

If needed, manually upgrade packages:
```bash
calculinux-upgrade-check --upgrade
```

## Package Operations

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
opkg flag hold package-name   # Prevent upgrades
opkg flag ok package-name     # Allow upgrades
```

## Troubleshooting

### Packages Not Working After Update

```bash
# Check and upgrade
calculinux-upgrade-check --upgrade

# Reinstall specific package
opkg remove package-name
opkg install package-name

# Check dependencies
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

### View Logs

```bash
# General system logs
journalctl -xe

# RAUC upgrade logs
journalctl -t rauc-pre-install
journalctl -u rauc-install-packages.service
```

## Examples

### Development Tools
```bash
opkg install python3 git vim make gcc
```

### Network Utilities
```bash
opkg install curl wget rsync
```

### System Tools
```bash
opkg install tmux htop iotop
```

### Web Server
```bash
opkg install nginx
systemctl enable --now nginx
```

## Advanced

### Installing Local Package Files
```bash
opkg install /path/to/package.ipk
```

### Manual Software in /opt
The `/opt` directory persists across updates for manually-installed software:
```bash
cd /opt
wget https://example.com/software.tar.gz
tar xzf software.tar.gz
```

**Note:** Use opkg when possible. `/opt` is for software not available as packages.

## More Information

For technical details about RAUC upgrades, package caching, and A/B safety, see:
- [rauc-package-management.md](rauc-package-management.md) - Technical details
- [rauc-upgrade-common-library.md](rauc-upgrade-common-library.md) - API reference
