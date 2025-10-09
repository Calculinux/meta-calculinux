# Calculinux Documentation

## Package Management Documentation

### For Users

**[user-package-management.md](user-package-management.md)** - User guide for package management
- Installing and removing packages with opkg
- Understanding system updates (minor vs major)
- Package operations (hold, info, etc.)
- Troubleshooting common issues
- Usage examples

### For Developers & System Integrators

**[rauc-package-management.md](rauc-package-management.md)** - Complete technical guide
- Architecture overview (filesystem layout, overlayfs, OPKG)
- A/B safety principles and constraints
- Complete upgrade flow (pre-install → post-install → first-boot)
- Error handling and rollback scenarios
- Testing procedures and troubleshooting
- Performance characteristics
- Design decisions and rationale

**[rauc-upgrade-common-library.md](rauc-upgrade-common-library.md)** - Developer API reference
- Complete function documentation
- Version management functions
- Network operations
- Package cache management
- Logging utilities
- Usage examples for each function

## Quick Reference

### Key Components

**RAUC Hooks:**
- `pre-install.sh` - Downloads packages before upgrade
- `post-install.sh` - Updates configuration after upgrade
- `rauc-install-packages.sh` - Installs packages on first boot (after boot verification)

**Supporting Files:**
- `rauc-upgrade-common.sh` - Shared library with 23+ functions
- `rauc-install-packages.service` - systemd service for first-boot installation

### Important Paths

- System version: `/data/overlay/etc/upper/calculinux-version`
- Package cache: `/data/overlay/var/cache/opkg-upgrade/`
- User packages: `/data/overlay/usr/local/upper/`
- RAUC hooks: `/usr/lib/rauc/`
- OPKG config: `/etc/opkg/opkg.conf`

### Critical Safety Principle

**Packages are installed AFTER boot is verified successful, not during upgrade.**

This ensures that if a new slot fails to boot and RAUC rolls back to the old slot, the old slot still has its original, compatible packages intact. The `/data/overlay` partition is shared between both A and B slots, so any changes to it affect both slots.

---

**Start with:** [user-package-management.md](user-package-management.md) for basic usage  
**Deep dive:** [rauc-package-management.md](rauc-package-management.md) for technical details
