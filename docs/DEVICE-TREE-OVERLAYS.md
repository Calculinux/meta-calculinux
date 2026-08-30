# Device Tree Overlays for Calculinux

Calculinux applies device tree overlays by merging them into a per-RAUC-slot FIT
image at boot (`merge-dt-overlays-boot`). Edit `/etc/device-tree-overlays.conf`,
reboot, and U-Boot loads `/data/fit/zboot_merged_<slot>.img` (or falls back to
`/boot/zboot_merged.img`).

Compiled overlays ship under `/boot/devicetree/` (package `picocalc-dt-overlays`).

## Available Overlays

### DS3231 I2C RTC Module

**File**: `/boot/devicetree/ds3231-rtc.dtbo`  
**Recipe**: `picocalc-dt-overlays`  
**Documentation**: [DS3231-RTC.md](DS3231-RTC.md)

Enables the Maxim DS3231 Real-Time Clock module on I2C bus 2.

### I2C Bus 2 @ 100 kHz

**File**: `/boot/devicetree/100khz-i2c.dtbo`  
**Recipe**: `picocalc-dt-overlays`

Reduces the I2C2 bus clock from 400 kHz to 100 kHz.

## Enabling Overlays

List overlay names (with or without `.dtbo`) or absolute paths in
`/etc/device-tree-overlays.conf`, one per line. Comments (`#`) and blank lines
are ignored. Example:

```
# ds3231-rtc
# sx1262-lora
```

After saving, reboot. `merge-dt-overlays-boot` rebuilds this slot’s merged FIT
on `/data`; the next boot uses it.

## Creating New Overlays

### 1. Add Overlay Source to picocalc-drivers

Create a `*-overlay.dts` under `overlays/` or `luckfox-lyra/overlays/` in
[picocalc-drivers](https://github.com/Calculinux/picocalc-drivers):

```dts
/dts-v1/;
/plugin/;

&i2c2 {
    status = "okay";

    my_device: device@addr {
        compatible = "vendor,device";
        reg = <0xaddr>;
    };
};
```

Add any new label references to `overlays/overlay-symbols.txt` so the kernel
recipe injects them into the base DTB for `fdtoverlay`.

### 2. Update picocalc-drivers SRCREV

After committing to picocalc-drivers, update the commit hash in
`picocalc-drivers-source.inc`:

```bitbake
SRCREV = "<new-commit-hash>"
```

`picocalc-dt-overlays` builds all `*-overlay.dts` sources automatically.

## Common I2C Buses

The RK3506 on Luckfox Lyra has the following I2C buses available:

- **I2C2**: Used for expansion (e.g., DS3231 RTC)
  - SCL: GPIO pin IO4 (`rm_io4_i2c2_scl`)
  - SDA: GPIO pin IO5 (`rm_io5_i2c2_sda`)

Check the pinctrl configuration in device tree files for other available I2C buses.

## References

- [picocalc-drivers Repository](https://github.com/Calculinux/picocalc-drivers)
- Recipe: `merge-dt-overlays-boot`, `default-merged-fit`
