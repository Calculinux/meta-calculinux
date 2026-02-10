# Hibernate Support for PicoCalc

This document describes the hibernate (suspend-to-disk) feature for Calculinux on the PicoCalc device.

## Overview

Hibernate allows the PicoCalc to save its current state to disk and completely power off. When powered back on, the system resumes exactly where it left off, preserving all running programs and open files.

## Storage Location

The hibernate image is stored in the **swap partition** on the main SD card in the Luckfox Lyra. The system uses a 1GB swap partition, which is more than sufficient for the 128MB of RAM.

### Why SD Card Swap, Not On-Board Flash?

While some Luckfox Lyra models have optional SPI NAND flash (128MB-1GB), we use the SD card swap partition instead because:

1. **Compatibility**: Not all Lyra boards have SPI NAND (the recommended base model doesn't)
2. **Boot Priority**: Users with NAND models are instructed to erase it for SD card boot
3. **Sufficient Space**: The 1GB swap partition provides ample space (8x the RAM size)
4. **Simplicity**: Using swap on the boot device requires no additional configuration

## Using Hibernate

### Manual Hibernation

To manually hibernate the system:

```bash
sudo systemctl hibernate
```

The system will:
1. Write all RAM contents to the swap partition
2. Power off completely
3. On next boot, automatically resume from the hibernate image

### Automatic Suspend-then-Hibernate

Systemd can be configured to automatically hibernate after a period of suspend:

```bash
sudo systemctl suspend-then-hibernate
```

This will suspend to RAM initially (low power), then hibernate after 2 hours (configurable in `/etc/systemd/sleep.conf`).

### Checking Hibernate Status

To verify hibernate is working:

```bash
# Check if swap is active
swapon --show

# Check hibernate configuration
cat /sys/power/disk
cat /sys/power/state

# Verify kernel knows about resume device
cat /proc/cmdline | grep resume
# Should show: resume=PARTLABEL=SWAP
```

## Configuration

### Systemd Sleep Configuration

The file `/etc/systemd/sleep.conf` controls hibernate behavior:

```ini
[Sleep]
AllowHibernation=yes
HibernateMode=platform shutdown
HibernateState=disk
HibernateDelaySec=7200  # 2 hours for suspend-then-hibernate
```

### Resume Configuration

The kernel is configured to resume from the swap partition via the **kernel command line**:

```
resume=PARTLABEL=SWAP
```

This is passed in the U-Boot boot script bootargs, which tells the kernel to check the partition labeled "SWAP" for a hibernate image at the earliest possible moment during boot.

**Why kernel cmdline, not `/sys/power/resume`?**

- Calculinux uses **no initrd** (`noinitrd` in bootargs)
- Without initrd, userspace can't set `/sys/power/resume` early enough
- Kernel needs to know the resume device before userspace starts
- The `PARTLABEL=` syntax allows the kernel to find the partition by its GPT label

This approach is simple, reliable, and requires no runtime configuration.

## Technical Details

### Kernel Configuration

The following kernel options are enabled in `hibernate.cfg`:

- `CONFIG_HIBERNATION=y` - Core hibernation support
- `CONFIG_SWAP=y` - Swap partition support
- `CONFIG_PM_SLEEP=y` - Power management sleep states
- `CONFIG_ZSWAP=y` - ComprLZO compression for hibernate image

### Boot Configuration

The U-Boot boot script (`boot.scr.sh.in`) includes in bootargs:

```
resume=PARTLABEL=SWAP
```

This tells the kernel to check the partition labeled "SWAP" for a hibernate image during early boot, before any userspace processes start.on
- `CONFIG_CRYPTO_LZO=y` - Compression for hibernate image

### Partition Layout

The WIC image creates these partitions:

```
/dev/mmcblk0p1  - bootloader (idblock)
/dev/mmcblk0p2  - U-Boot
/dev/mmcblk0p3  - Trust
/dev/mmcblk0p4  - U-Boot environment
/dev/mmcblk0p5  - ROOT_A (2GB, active root filesystem)
/dev/mmcblk0p6  - ROOT_B (2GB, alternate root for updates)
/dev/mmcblk0p7  - SWAP (1GB, hibernate storage)
/dev/mmcblk0p8  - OVERLAY_DATA (2GB, user data persistence)
```

### Files Installed

The `hibernate-support` package installs:

- `/usr/sbin/hibernate-setup` - Setup script
- `/etc/systemd/sleep.conf` - Sleep configuration
- `/usr/lib/systemd/system/hibernate-setup.service` - Boot-time setup service

## Troubleshooting

### Hibernate Fails
etc/systemd/sleep.conf` - Systemd sleep configuration
1. **Swap is active**: `swapon --show` should show the SWAP partition
2. **Sufficient space**: Swap should be larger than RAM (1GB > 128MB ✓)
3. **Resume device set**: `cat /sys/power/resume` should show device major:minor
4. **Kernel support**: `cat /sys/power/state` should include "disk"

### Resume Fails

If the system doesn't resume after hibernating:

1. Check that the swap partition wasn't reformatted
2. Verify the hibernate image wasn't corrupted (power loss during hibernate)
3. Check kernel logs: `journalctl -b -1` (previous boot)

### Performance Optimization

To speed up hibernation:

- The kernel uses LZO compression by default for faster writes
- Hibernate time depends on RAM usage (less RAM used = faster hibernate)
- Resume is typically faster than hibernate

## Limitations

1. **Read-only root**: The system root is read-only, so hibernate image must be on swap
2. **RAUC updates**: Hibernate state is lost after A/B slot updates (expected behavior)
3. **Battery drain**: Unlike suspend, hibernate completely powers off (no battery drain)
4. **Resume time**: Resume takes longer than wake from suspend (~5-15 seconds)

## Future Enhancements

Potential improvements for hibernate support:

- [ ] Add hibernate support to power button handling
- [ ] Implement auto-hibernate on low battery
- [ ] Add hibernate progress indicator on LCD
- [ ] Support hibernating to SPI NAND for boards that have it
- [ ] Add resume boot splash screen

## References

- [systemd-suspend.service(8)](https://www.freedesktop.org/software/systemd/man/systemd-suspend.service.html)
- [systemd-sleep.conf(5)](https://www.freedesktop.org/software/systemd/man/systemd-sleep.conf.html)
- [Linux Kernel Power Management](https://www.kernel.org/doc/Documentation/power/swsusp.txt)
