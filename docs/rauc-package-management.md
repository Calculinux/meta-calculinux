# RAUC A/B Package Management for Calculinux

## Overview

Calculinux uses RAUC for A/B system updates combined with OPKG for user-installable packages. This document describes how packages are managed across major version upgrades while maintaining the safety guarantees of A/B updates.

## Architecture

### Filesystem Layout

Calculinux uses read-only rootfs with RAUC A/B updates. User-installed packages persist across system updates by installing to `/usr/local`, which is mounted as an overlayfs on the persistent `/data` partition.

**Partition Structure:**
- `/dev/mmcblk1p2` - Slot A (read-only rootfs)
- `/dev/mmcblk1p3` - Slot B (read-only rootfs)
- `/dev/mmcblk1p1` - `/data` (persistent, shared between slots)

**Mounted Filesystem:**
- `/` - Read-only rootfs (RAUC managed, A/B slots)
- `/usr` - Base system binaries and libraries
- `/usr/local` - User-installed packages (overlayfs → `/data/overlay/usr-local/`)
- `/opt` - Optional/manually-managed packages (overlayfs → `/data/overlay/opt/`)
- `/etc`, `/var`, `/home`, `/root` - Overlayfs for runtime changes
- `/data` - Persistent data partition

**Why `/usr/local`?**

Following the Filesystem Hierarchy Standard (FHS):
- `/usr` = Base system software (RAUC managed)
- `/usr/local` = Locally-installed software (user managed via opkg)

Benefits:
- ✅ Clear separation between system and user packages
- ✅ Standard Unix convention - familiar to administrators
- ✅ Already in default PATH on most systems
- ✅ Survives RAUC A/B updates naturally
- ✅ No version conflicts with base system

**OverlayFS Configuration:**

`/usr/local` is configured as an overlayfs in the preinit script:
- **Lower layer**: `/usr/local` from base image (typically empty)
- **Upper layer**: `/data/overlay/usr-local/upper` (user packages)
- **Work dir**: `/data/overlay/usr-local/work`

**OPKG Destinations:**

Two installation destinations in `/etc/opkg/opkg.conf`:
```conf
dest root /              # Base system (read-only, RAUC managed)
dest local /usr/local    # User packages (writable, persistent)
option dest local        # Default to /usr/local for user installs
```

Package files install to:
- Binaries: `/usr/local/bin`, `/usr/local/sbin`
- Libraries: `/usr/local/lib`
- Configuration: `/usr/local/etc`
- Data: `/usr/local/share`

### Key Components

**Filesystem Layout:**
- **Slot A/B**: `/dev/mmcblk1p2` and `/dev/mmcblk1p3` - Read-only root filesystems
- **Persistent Data**: `/data` - Persistent partition shared between slots
- **Package Overlay**: `/data/overlay/usr/local/upper` - User-installed packages
- **Package Cache**: `/data/overlay/var/cache/opkg-upgrade/` - Temporary upgrade cache

**RAUC Hooks:**
- `pre-install.sh` - Runs before update, downloads packages
- `post-install.sh` - Runs after update, prepares for first boot
- `rauc-install-packages.sh` - Runs on first boot after successful boot verification

**Supporting Files:**
- `rauc-upgrade-common.sh` - Shared library functions
- `rauc-install-packages.service` - systemd service for first-boot installation

### The A/B Safety Principle

**Critical Constraint:** `/data/overlay` is **shared between both slots**

This means:
- ✅ Changes to `/data/overlay` persist across reboots
- ❌ Changes to `/data/overlay` affect BOTH slots
- ⚠️ Installing packages modifies `/data/overlay/usr/local/upper`
- **Therefore:** Packages must NOT be installed until boot is verified successful

**Why this matters:**
```
Bad scenario if we install during post-install:
1. Post-install installs NEW packages to /data/overlay
2. Reboot to new slot
3. New slot fails to boot
4. RAUC rolls back to old slot
5. ❌ Old slot now has NEW packages = incompatible/broken!
```

**Safe approach - install on first boot:**
```
1. Post-install does NOT install packages
2. Reboot to new slot
3. New slot boots successfully
4. RAUC marks boot as "good"
5. ✅ Now it's safe - rollback won't happen
6. First-boot service installs packages
```

## Upgrade Flow

### Major Version Upgrade (e.g., Scarthgap → Walnascar)

#### Phase 1: Pre-Install (On Old Slot, Before Update)

```bash
┌─────────────────────────────────────────┐
│ pre-install.sh                          │
├─────────────────────────────────────────┤
│ 1. Detect version change                │
│ 2. Check network connectivity           │
│ 3. List user packages                   │
│ 4. Download ALL packages to cache:      │
│    /data/overlay/var/cache/opkg-upgrade/│
│ 5. Create version marker (.version)     │
│ 6. Warn user with cancellation option   │
└─────────────────────────────────────────┘
```

**Key Features:**
- Downloads all packages before committing to upgrade
- Stores version marker for rollback detection
- Provides user feedback and cancellation window
- Falls back gracefully if network unavailable

#### Phase 2: Post-Install (On Old Slot, After Update Written)

```bash
┌─────────────────────────────────────────┐
│ post-install.sh                         │
├─────────────────────────────────────────┤
│ 1. Verify cache exists                  │
│ 2. Update opkg.conf to new version URLs │
│ 3. Log that packages will install later │
│ 4. Exit (NO package installation!)      │
└─────────────────────────────────────────┘
```

**Critical:** Only configuration changes, no package installation

#### Phase 3: First Boot (On New Slot, After Boot Verified)

```bash
┌─────────────────────────────────────────┐
│ rauc-install-packages.service           │
├─────────────────────────────────────────┤
│ After=rauc-mark-good.service            │
│ Runs rauc-install-packages.sh:         │
│                                         │
│ 1. Check cache version matches system   │
│ 2. For each package:                    │
│    - Try cache first                    │
│    - Fall back to network if needed     │
│ 3. Clean up cache on success            │
│ 4. Keep cache on failure (for recovery) │
└─────────────────────────────────────────┘
```

**Safety Features:**
- Only runs after boot verified successful
- Version check prevents wrong packages after rollback
- Network fallback for missing cached packages
- Retry logic (up to 3 attempts)
- Preserves cache on failure for manual recovery

### Minor Version Update (e.g., Scarthgap patch)

For minor updates within the same major version:

```bash
┌─────────────────────────────────────────┐
│ post-install.sh                         │
├─────────────────────────────────────────┤
│ 1. No version change detected           │
│ 2. Run calculinux-upgrade-check --auto  │
│ 3. Smart upgrade only changed packages  │
└─────────────────────────────────────────┘
```

No pre-download or first-boot installation needed.

## Common Library Functions

The `rauc-upgrade-common.sh` library provides shared functions:

### Version Management
- `get_current_version()` - Read system version
- `set_current_version(version)` - Update system version
- `is_major_version_upgrade(old, new)` - Detect major version change

### Network Operations
- `check_network_connectivity()` - Test network availability

### Package Operations
- `check_opkg_available()` - Verify opkg installed
- `get_installed_package_count()` - Count packages
- `get_installed_packages()` - List package names

### Cache Management
- `create_package_cache()` - Create cache directory
- `has_package_cache()` - Check if cache exists with packages
- `get_cached_package_count()` - Count cached .ipk files
- `find_cached_package(name)` - Find .ipk file by package name
- `cleanup_package_cache()` - Remove cache directory

### Configuration
- `backup_opkg_config(path)` - Backup opkg.conf
- `restore_opkg_config(path)` - Restore opkg.conf

### User Interaction
- `wait_with_cancel(seconds, message)` - Countdown with Ctrl+C option

### Logging
- `log_info(message)` - Info to stdout and journal
- `log_warning(message)` - Warning to stderr and journal  
- `log_error(message)` - Error to stderr and journal

## Rollback Scenario

### What Happens During Rollback?

```
1. New slot fails to boot (kernel panic, service failure, etc.)
2. Watchdog or RAUC detects boot failure
3. Bootloader switches back to old slot
4. Old slot boots normally
```

**State after rollback:**
- Slot A (old): Running with OLD packages ✅
- Slot B (new): Failed, not used
- `/data/overlay`: Unchanged (OLD packages) ✅
- Cache: Contains NEW version packages
- opkg.conf: Points to NEW version (written during post-install)

**First-boot service behavior:**
```bash
# Service runs and checks version
CACHE_VERSION="walnascar"  # From .version marker
CURRENT_VERSION="scarthgap"  # From /etc/calculinux-version

if [ "$CACHE_VERSION" != "$CURRENT_VERSION" ]; then
    log_warning "Cache version mismatch - rollback detected"
    cleanup_package_cache
    exit 0
fi
```

**Result:** Cache cleaned up, no packages installed, system fully functional ✅

## Error Handling

### Pre-Install Failures

**Scenario: Network unavailable**
- User warned: "No network connectivity"
- 10-second cancellation window
- If continued: upgrade proceeds, first-boot attempts network download

**Scenario: Partial download**
- Some packages cached, others failed
- User warned about missing packages
- Upgrade proceeds
- First-boot installs cached packages, downloads missing ones

### First-Boot Failures

**Scenario: Package installation fails**
- Base system functional (rootfs is intact)
- Failed packages logged
- Cache preserved for manual recovery
- Service retries (up to 3 times)

**Manual recovery:**
```bash
# Check status
systemctl status rauc-install-packages.service
journalctl -u rauc-install-packages.service

# Retry
systemctl restart rauc-install-packages.service

# Manual install
cd /data/overlay/var/cache/opkg-upgrade
opkg install --force-reinstall *.ipk

# Cleanup
rm -rf /data/overlay/var/cache/opkg-upgrade
```

**Scenario: Service timeout (>10 minutes)**
- systemd kills service
- Partial installation possible
- Cache preserved
- Automatic retry on next boot

## Configuration

### BitBake Recipe

The `rauc-conf.bbappend` installs all components:

```bitbake
inherit systemd

SRC_URI:append := "\
    file://rauc-upgrade-common.sh \
    file://pre-install.sh \
    file://post-install.sh \
    file://rauc-install-packages.sh \
    file://rauc-install-packages.service \
"

# Scripts installed to /usr/lib/rauc/
# Service installed to /usr/lib/systemd/system/
# Service auto-enabled via systemd
```

### Version Tracking

**File:** `/data/overlay/etc/upper/calculinux-version`

Contains the major version name (e.g., "scarthgap", "walnascar").

**Updated by:** `post-install.sh` after successful upgrade

**Used by:**
- `pre-install.sh` - Detect version change
- `rauc-install-packages.sh` - Validate cache version

### Package Feeds

Package feeds are organized by Yocto release codename and automatically configured:

```
https://opkg.calculinux.org/ipk/scarthgap/    # Scarthgap (5.2)
https://opkg.calculinux.org/ipk/walnascar/    # Walnascar (6.0)
https://opkg.calculinux.org/ipk/wrynose/      # Wrynose (future)
```

The feed URL is automatically set during image build and updated by `post-install.sh` after upgrades to match the new system version.

### Cache Version Marker

**File:** `/data/overlay/var/cache/opkg-upgrade/.version`

Created by `pre-install.sh` during package download.

Contains the target version name (e.g., "walnascar").

Used by `rauc-install-packages.sh` to detect rollback scenarios.

## Testing

### Test Plan

#### 1. Normal Major Upgrade
```
1. Start with packages installed
2. Initiate major upgrade
3. Verify pre-download succeeds
4. Reboot
5. Verify new slot boots
6. Verify rauc-install-packages.service runs
7. Verify all packages installed from cache
8. Verify cache cleaned up
```

#### 2. Rollback Scenario
```
1. Perform major upgrade
2. Packages cached successfully
3. Force new slot boot failure (e.g., corrupt systemd)
4. Verify RAUC rolls back
5. Verify old slot boots normally
6. Verify old packages still work
7. Verify first-boot service detects version mismatch
8. Verify cache cleaned up without installing
```

#### 3. Network Failure
```
1. Disconnect network
2. Attempt major upgrade
3. Verify user warned
4. Continue upgrade
5. Reboot
6. Reconnect network
7. Verify packages download and install on first boot
```

#### 4. Partial Cache
```
1. Pre-download with some packages failing
2. Complete upgrade
3. Reboot
4. Verify cached packages install from cache
5. Verify missing packages download from network
```

### Validation Commands

```bash
# Check version
cat /data/overlay/etc/upper/calculinux-version

# Check cache
ls -lh /data/overlay/var/cache/opkg-upgrade/

# Check cache version
cat /data/overlay/var/cache/opkg-upgrade/.version

# Check service status
systemctl status rauc-install-packages.service

# Check service logs
journalctl -u rauc-install-packages.service

# Check installed packages
opkg list-installed

# Force service run (testing)
systemctl restart rauc-install-packages.service

# Manual cache cleanup
rm -rf /data/overlay/var/cache/opkg-upgrade/
```

## Troubleshooting

### Symptom: Packages not installing on first boot

**Check:**
```bash
# Is service enabled?
systemctl is-enabled rauc-install-packages.service

# Does cache exist?
ls /data/overlay/var/cache/opkg-upgrade/

# Check service conditions
systemctl cat rauc-install-packages.service | grep Condition

# Check service status
systemctl status rauc-install-packages.service
```

**Common causes:**
- Cache doesn't exist (pre-install failed)
- Version mismatch (rollback occurred)
- Service disabled
- Lock file exists (`/run/rauc-install-packages.lock`)

### Symptom: Old packages after rollback

**This should NOT happen!** If it does:

```bash
# Check version
cat /data/overlay/etc/upper/calculinux-version

# Check what slot is active
rauc status

# Force reinstall from current version
calculinux-upgrade-check --upgrade --force
```

### Symptom: Cache not cleaned up

**Check:**
```bash
# Check service logs for errors
journalctl -u rauc-install-packages.service

# Check if packages installed
opkg list-installed

# Manual cleanup
rm -rf /data/overlay/var/cache/opkg-upgrade/
```

**Common causes:**
- Installation failed (cache intentionally preserved)
- Service crashed before cleanup
- Disk space issues

## Design Decisions

### Why Not Install During Post-Install?

**Answer:** A/B safety

Installing packages during post-install modifies `/data/overlay`, which is shared between slots. If the new slot fails to boot and rolls back, the old slot would have incompatible new packages.

### Why Use systemd Service Instead of Init Script?

**Answer:** Dependencies and ordering

systemd provides:
- `After=rauc-mark-good.service` - Run after boot verified
- `ConditionPathExists=` - Only run if cache exists
- Automatic retry logic
- Journal integration
- Better process management

### Why Keep Cache on Failure?

**Answer:** Manual recovery

If package installation fails, keeping the cache allows the user to:
- Inspect what was downloaded
- Manually install packages
- Debug what went wrong
- Retry without re-downloading

### Why Network Fallback?

**Answer:** Robustness

If cache is incomplete:
- Some packages pre-downloaded
- Others missing (network failure during pre-install)
- First-boot can still succeed by downloading missing packages

## Performance

### Boot Time Impact

**First boot after upgrade:**
- Additional ~5-30 seconds (cache install)
- Additional ~30-300 seconds (network install)

**Subsequent boots:**
- No impact (service exits immediately if no cache)

### Disk Space

**Cache size:** ~10-50 MB (typical)
- Varies based on number/size of packages
- Temporary (cleaned up after installation)
- Located on persistent partition (plenty of space)

### Network Usage

**Pre-install:** Downloads all packages once
**First-boot:** Only downloads if cache incomplete

**Total:** Same as old approach, better distributed

## Comparison with Previous Approach

| Aspect | Old (Chroot) | New (First-Boot) |
|--------|--------------|------------------|
| **A/B Safety** | ❌ Broken | ✅ Maintained |
| **Complexity** | High (368 lines) | Low (104 lines) |
| **Rollback** | ❌ Broken system | ✅ Fully functional |
| **Recovery** | Difficult | Easy |
| **Boot Time** | Same total | Slightly delayed |
| **Testability** | Hard (chroot) | Easy (real env) |

## Future Enhancements

### Potential Improvements

1. **Progress Indication** - Show package installation progress during boot
2. **Parallel Installation** - Install multiple packages concurrently
3. **Delta Updates** - Only download changed files (casync)
4. **Pre-validation** - Verify signatures and dependencies before upgrade
5. **Bandwidth Control** - Limit download speed during first boot

### Known Limitations

1. **First-boot delay** - Additional time after upgrade (acceptable trade-off)
2. **Network dependency** - Need network if cache incomplete (fallback available)
3. **No atomicity** - Partial installation possible (mitigated by retry logic)

## See Also

- [rauc-upgrade-common-library.md](rauc-upgrade-common-library.md) - Common library API reference
- [user-package-management.md](user-package-management.md) - User guide for package management
- `calculinux-upgrade-check` - Manual upgrade tool
- [RAUC Documentation](https://rauc.readthedocs.io/) - Official RAUC docs
- [OPKG Documentation](https://openwrt.org/docs/guide-user/additional-software/opkg) - OPKG package manager

---

**Document Version:** 2.1 (Consolidated with overlay filesystem architecture)  
**Last Updated:** October 2025  
**Status:** Current Implementation
