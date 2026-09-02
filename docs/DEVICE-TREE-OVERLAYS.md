# Device Tree Overlays for Calculinux

Calculinux can apply overlays in two ways:

- **Persistent (FIT-at-boot)**: list names in `/etc/device-tree-overlays.conf`, reboot. `merge-dt-overlays-boot` writes `/data/fit/zboot_merged_<slot>.img` for this RAUC slot. U-Boot prefers that FIT, then `/boot/zboot_merged.img`, then unmerged `zboot.img`.
- **Runtime (ConfigFS)**: apply a `.dtbo` now. Does not persist across reboot. Works for I2C-child overlays such as DS3231. Overlays that add new pinctrl groups need the FIT path (or unused groups already in the base DTB).

Compiled overlays ship in both `/boot/devicetree/` (FIT) and `/lib/firmware/overlays/` (ConfigFS). Package: `picocalc-dt-overlays`.

## Available Overlays

### DS3231 I2C RTC Module

**File**: `ds3231-rtc.dtbo`  
**Documentation**: [DS3231-RTC.md](DS3231-RTC.md)

Enables the Maxim DS3231 Real-Time Clock on I2C bus 2.

### I2C Bus 2 @ 100 kHz

**File**: `100khz-i2c.dtbo`

Reduces the I2C2 bus clock from 400 kHz to 100 kHz.

## Persistent: merge for next boot

Edit `/etc/device-tree-overlays.conf` (one name or absolute `.dtbo` path per line):

```
ds3231-rtc
```

Reboot. `merge-dt-overlays-boot` rebuilds this slot’s FIT on `/data`. A RAUC update deletes that slot’s merged FIT so the first boot uses `/boot/zboot_merged.img` (same kernel, no user overlays) until merge runs again.

Names resolve in `/etc/devicetree/`, then `/boot/devicetree/`, then `/lib/firmware/overlays/`.

Self-check (from the source tree):

```bash
bash meta-calculinux-distro/recipes-core/systemd/files/merge-dt-overlays-boot-check.sh
```

## Runtime: ConfigFS

```bash
mkdir -p /sys/kernel/config/device-tree/overlays/ds3231
cat /lib/firmware/overlays/ds3231-rtc.dtbo > /sys/kernel/config/device-tree/overlays/ds3231/dtbo
cat /sys/kernel/config/device-tree/overlays/ds3231/status
```

Writing the dtbo applies the overlay. ConfigFS apply does not persist.

## Creating New Overlays

Add `*-overlay.dts` under `devicetree-overlays/`, `overlays/`, or `luckfox-lyra/overlays/` in [picocalc-drivers](https://github.com/Calculinux/picocalc-drivers). Put new label references in `overlays/overlay-symbols.txt`. Bump `SRCREV` in `picocalc-drivers-source.inc`. `picocalc-dt-overlays` builds all of them.

## Kernel Support

- Selective `__symbols__` in the base DTB (kernel recipe) for ConfigFS and `fdtoverlay`
- `CONFIG_OF_OVERLAY=y` and `CONFIG_OF_CONFIGFS=y` (`dto.cfg`)
- ConfigFS patch: `0001-of-configfs-overlay-interface.patch`

## References

- [Linux overlay notes](https://www.kernel.org/doc/html/latest/devicetree/overlay-notes.html)
- [picocalc-drivers](https://github.com/Calculinux/picocalc-drivers)
