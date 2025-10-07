# OPKG with Read-Only Rootfs Implementation

## Overview

Calculinux uses read-only rootfs with RAUC A/B updates. User-installed packages persist across system updates by installing to `/usr/local`, which is mounted as an overlayfs on the persistent `/data` partition.

## Architecture

### Filesystem Layout
- `/` - Read-only rootfs (RAUC managed, A/B slots)
- `/usr` - Base system binaries and libraries
- `/usr/local` - User-installed packages (overlayfs → `/data/overlay/usr-local/`)
- `/opt` - Optional/manually-managed packages (overlayfs → `/data/overlay/opt/`)
- `/etc`, `/var`, `/home`, `/root` - Overlayfs for runtime changes
- `/data` - Persistent data partition (mmcblk1p1)

### Why `/usr/local`?

Following the Filesystem Hierarchy Standard (FHS):
- `/usr` = Base system software (RAUC managed)
- `/usr/local` = Locally-installed software (user managed via opkg)

Benefits:
- ✅ Clear separation between system and user packages
- ✅ Standard Unix convention - familiar to administrators
- ✅ Already in default PATH on most systems
- ✅ Survives RAUC A/B updates naturally
- ✅ No version conflicts with base system

## Implementation

### 1. Overlayfs Configuration

`/usr/local` is added to the overlayfs list in the preinit script:

```bash
OVERLAYS="/etc /root /home /var /usr/local /opt"
```

- **Lower layer**: `/usr/local` or `/opt` from base image (typically empty)
- **Upper layer**: `/data/overlay/{usr-local,opt}/upper` (user packages)
- **Work dir**: `/data/overlay/{usr-local,opt}/work`

Note: `/opt` is available for manually-managed software packages. While opkg installs to `/usr/local`, knowledgeable users can use `/opt` for custom software following Unix conventions.

### 2. OPKG Configuration

Two installation destinations configured in `/etc/opkg/opkg.conf`:

```conf
dest root /              # Base system (read-only, RAUC managed)
dest local /usr/local    # User packages (writable, persistent)

option dest local        # Default to /usr/local for user installs
```

### 3. Package Installation

Users install packages normally:

```bash
opkg update
opkg install vim    # Installs to /usr/local by default
```

Files are installed to:
- Binaries: `/usr/local/bin`, `/usr/local/sbin`
- Libraries: `/usr/local/lib`
- Configuration: `/usr/local/etc`
- Data: `/usr/local/share`

### 4. System Updates with RAUC

**Update Process**:
1. RAUC installs new rootfs to inactive slot (A→B or B→A)
2. System reboots to new slot
3. `/usr/local` overlayfs remounts with same upper layer
4. User packages remain accessible
5. RAUC post-install hook automatically checks compatibility

**Automatic Upgrade Check**:
- Post-install hook runs `calculinux-upgrade-check --auto`
- Detects outdated packages and library mismatches
- Automatically upgrades packages when possible
- Logs results to system journal

**Manual Check**:
Users can manually verify after updates:
```bash
calculinux-upgrade-check           # Check only
calculinux-upgrade-check --upgrade # Check and upgrade
```

## Package Version Management

### Version-Specific Feeds

Package feeds are organized by Yocto release codename:
```
https://opkg.calculinux.org/ipk/scarthgap/    # Scarthgap (5.2)
https://opkg.calculinux.org/ipk/walnascar/    # Walnascar (6.0)
https://opkg.calculinux.org/ipk/wrynose/      # Wrynose (future)
```

The feed URLs are automatically set during image build and stored in `/etc/opkg/opkg.conf`.

### Minor Updates (e.g., 5.2.3 → 5.2.4)
- Usually compatible - no action needed
- RAUC hook runs smart upgrade check
- Only incompatible packages are upgraded

### Major Updates (e.g., Scarthgap → Walnascar)
- Library versions and ABIs may change
- RAUC **pre-install hook warns user** about major upgrade
  - Lists packages that will be reinstalled
  - Checks network connectivity
  - Estimates download size
  - Gives option to cancel if no network available
- RAUC **post-install hook automatically force-reinstalls ALL packages**
- Ensures complete compatibility with new base system
- Uses new version-specific feed automatically

### Upgrade Workflow

**Automatic (during RAUC install):**
```
1. RAUC begins bundle installation (e.g., Walnascar)
2. Pre-install hook detects version change
3. Compares: scarthgap (old) vs walnascar (new)
4. Major upgrade detected → Displays warning:
   - Lists all packages to be reinstalled
   - Checks network connectivity to package repository
   - Estimates download size (~1MB per package)
   - Gives user 10 seconds to cancel (Ctrl+C)
5. RAUC installs new system to inactive slot
6. System reboots to new slot
7. Post-install hook runs:
   - Updates /etc/opkg/opkg.conf feed URLs to match new version
   - Runs opkg update to fetch new package lists
   - Force reinstalls ALL user packages from new feeds
   - Logs results to journal
```

**For minor updates:**
```
1. RAUC installs patch/point release
2. Post-install hook detects same major version
3. Runs calculinux-upgrade-check --auto
4. Upgrades only incompatible packages
```

**Manual check (if needed):**
```bash
calculinux-upgrade-check --upgrade
```

### Why This Works

- **No version suffixes needed**: Packages reinstalled from new feed automatically
- **Complete compatibility**: Force reinstall ensures everything matches new base system
- **Efficient**: Only reinstalls on major upgrades, not minor updates
- **Simple**: No complex dependency tracking or version management
- **Reliable**: opkg `--force-reinstall` guarantees clean state
- **User-aware**: Pre-install warning allows cancellation if network unavailable

### Future: Offline Bundle Support

For major upgrades without network connectivity, a future enhancement could bundle common packages alongside the system image:

```
calculinux-bundle.raucb          # Main system image
├─ rootfs.ext4                   # Base system
└─ packages/                     # Sidecar package cache
    ├─ vim_9.1-r0_luckfox-lyra.ipk
    ├─ git_2.43-r0_luckfox-lyra.ipk
    └─ python3_3.12-r0_luckfox-lyra.ipk

Post-install process:
1. Check for bundled packages directory
2. If found, install from local cache first
3. Fall back to network for missing packages
```

This would enable limited offline major upgrades for systems with commonly-used packages.

## Troubleshooting

### Check package status
```bash
calculinux-upgrade-check
```

### Upgrade outdated packages
```bash
calculinux-upgrade-check --upgrade
```

### Reinstall problematic package
```bash
opkg remove package-name
opkg install package-name
```

### Check library dependencies
```bash
ldd /usr/local/bin/binary-name
```

## Technical Details

### Boot Sequence
1. Kernel loads read-only rootfs (RAUC slot)
2. Preinit mounts `/data` partition
3. Preinit sets up overlayfs for `/etc`, `/var`, `/home`, `/root`, `/usr/local`
