# RAUC Package Upgrade with Chroot Strategy

## Overview

When performing a major version upgrade via RAUC, user-installed packages in `/usr/local` must be reinstalled to ensure compatibility with the new system libraries. This document explains the chroot strategy used to safely reinstall packages in the context of the new system environment **before** rebooting.

## The Problem

When RAUC installs a new system image:
1. New rootfs is written to the inactive slot (e.g., A→B)
2. Post-install hook runs **before** reboot
3. Hook is still running in the **old** system environment (Slot A)
4. Need to reinstall packages for the **new** system environment (Slot B)

If we simply run `opkg install` in the current environment:
- ❌ opkg binaries are from old system
- ❌ Package postinst scripts run with old libraries
- ❌ Potential compatibility issues

## The Solution: Chroot into New System

Create a temporary chroot environment that combines:
- **Lower layer**: New slot's rootfs (read-only)
- **Upper layers**: Existing persistent overlays from `/data`

This gives us:
- ✅ New system binaries and libraries
- ✅ Postinst scripts run in new environment
- ✅ Package installations write to production overlays
- ✅ After reboot, everything is already correct

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Running System (Slot A - Old Version)                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  /tmp/upgrade-chroot/  ← Temporary mount point             │
│    │                                                         │
│    ├── /etc → overlay(lower=Slot B, upper=/data/overlay/etc)│
│    ├── /var → overlay(lower=Slot B, upper=/data/overlay/var)│
│    ├── /usr/local → overlay(lower=Slot B, upper=/data/.../usr-local)│
│    ├── /proc → bind from host                               │
│    ├── /sys → bind from host                                │
│    └── /dev → bind from host                                │
│                                                              │
│  chroot /tmp/upgrade-chroot opkg install --force-reinstall  │
│         ↓                                                    │
│  Runs in Slot B environment                                 │
│  Writes to /data overlays (persistent)                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Steps

### 1. Mount New Slot (Read-Only)
```bash
mkdir -p /tmp/new-slot
mount -o ro /dev/mmcblk1p3 /tmp/new-slot  # Slot B device
```

### 2. Create Chroot with Overlays
```bash
CHROOT_DIR="/tmp/upgrade-chroot"
DATA_MOUNT="/data"  # Where overlays live

for overlay in /etc /var /usr/local /opt; do
    # Overlay structure in /data
    UPPER="$DATA_MOUNT/overlay/$overlay/upper"
    WORK="$DATA_MOUNT/overlay/$overlay/work"
    
    # Mount overlay in chroot
    mount -t overlay overlay \
        -o lowerdir=/tmp/new-slot$overlay \
        -o upperdir=$UPPER \
        -o workdir=$WORK \
        $CHROOT_DIR$overlay
done
```

### 3. Mount Essential System Directories
```bash
mount -t proc proc $CHROOT_DIR/proc
mount -t sysfs sys $CHROOT_DIR/sys
mount -o bind /dev $CHROOT_DIR/dev
mount -o bind /run $CHROOT_DIR/run
```

### 4. Run Package Operations in Chroot
```bash
# Update package lists (with new version URLs)
chroot $CHROOT_DIR /usr/bin/opkg update

# Reinstall all packages
chroot $CHROOT_DIR /usr/bin/opkg list-installed | while read pkg _; do
    chroot $CHROOT_DIR /usr/bin/opkg install --force-reinstall "$pkg"
done
```

### 5. Cleanup
```bash
umount $CHROOT_DIR/{proc,sys,dev,run}
umount $CHROOT_DIR/{etc,var,usr/local,opt}
umount /tmp/new-slot
rm -rf $CHROOT_DIR /tmp/new-slot
```

### 6. Reboot
System reboots to Slot B with packages already reinstalled correctly.

## Key Design Points

### Multiple Overlay Mounts
The same overlay upper directories from `/data` can be mounted in multiple places:
1. **Production mount**: Used when booting normally
2. **Chroot mount**: Used temporarily during upgrade

This is safe because:
- Overlays are designed to support this
- We're not accessing the same overlay mount from different contexts
- The kernel handles the consistency

### Read-Only Slot Mount
The new slot is mounted read-only because:
- We don't need to write to it
- Safety: prevents accidental modification
- The slot will be used as lower layer anyway (read-only by design)

### Fallback Mechanism
If chroot setup fails (e.g., RAUC_SLOT_NAME not set), the script falls back to:
- Simple reinstall in current environment
- Still better than nothing
- User can run `calculinux-upgrade-check` after reboot if issues occur

## Environment Variables from RAUC

RAUC provides environment variables to hooks:
- `RAUC_SLOT_NAME`: Name of the slot being updated (e.g., "A", "B", "rootfs.0", "rootfs.1")
- Other RAUC vars available but not currently used

## Advantages

1. **True compatibility**: Postinst scripts run with new libraries
2. **Network efficiency**: No need to download/reinstall after reboot
3. **Boot time**: System is ready immediately after reboot
4. **Safety**: Writes to persistent storage, survives failures
5. **Elegance**: Leverages existing overlay infrastructure

## Potential Issues & Mitigations

### Issue: Chroot Setup Failure
**Mitigation**: Fallback to simple reinstall + post-boot check tool

### Issue: Network Unavailable During Hook
**Mitigation**: Pre-install warning checks network, gives cancellation option

### Issue: Package Repository Down
**Mitigation**: Graceful failure, user can retry with `calculinux-upgrade-check`

### Issue: Disk Space
**Mitigation**: Overlay partition is auto-grown during preinit

## Testing Recommendations

1. **Major upgrade with packages installed**
   - Install several packages (vim, git, python3)
   - Perform major version upgrade
   - Verify packages work immediately after reboot

2. **Chroot failure scenario**
   - Test with RAUC_SLOT_NAME unset
   - Verify fallback works

3. **Network failure during upgrade**
   - Disconnect network before upgrade
   - Verify warning appears
   - Verify cancellation works

4. **Complex package postinst scripts**
   - Install package with systemd service
   - Verify service installed correctly after upgrade

## Future Enhancements

### Offline Package Bundles
Bundle common packages with RAUC image:
```
calculinux-bundle.raucb
  ├── rootfs.ext4
  └── packages/
      ├── vim_*.ipk
      ├── git_*.ipk
      └── python3_*.ipk
```

Post-install hook could:
1. Check for bundled packages directory
2. Install from local cache first
3. Fall back to network for missing packages

This would enable offline major upgrades for systems with commonly-used packages.

## Comparison with Alternatives

### Alternative 1: Post-Boot Service
- ❌ Longer boot time (waiting for package reinstall)
- ❌ System might be used before packages ready
- ✅ Simpler implementation

### Alternative 2: Pre-Build Package List
- ❌ User must specify packages in advance
- ❌ Not flexible for ad-hoc installs
- ✅ Faster upgrades

### Alternative 3: Current Chroot Approach
- ✅ Immediate availability after reboot
- ✅ True compatibility
- ✅ Flexible (works with any packages)
- ⚠️ More complex implementation
- ⚠️ Requires disk space for temporary mounts

## Conclusion

The chroot approach provides the best balance of:
- **Safety**: Packages install in correct environment
- **Performance**: No post-boot delay
- **Flexibility**: Works with any packages
- **Robustness**: Fallback mechanisms for failures

This strategy makes Calculinux a robust platform for user package management across major system upgrades.
