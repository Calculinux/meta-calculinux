# Device Tree Overlays for Calculinux

Calculinux supports runtime device tree overlays using the kernel's ConfigFS interface, allowing you to enable hardware modules without rebuilding the entire image.

## Available Overlays

### DS3231 I2C RTC Module

**File**: `/lib/firmware/overlays/ds3231-rtc.dtbo`  
**Recipe**: `picocalc-dt-overlays`  
**Documentation**: [DS3231-RTC.md](DS3231-RTC.md)

Enables the Maxim DS3231 Real-Time Clock module on I2C bus 2.

### I2C Bus 2 @ 100 kHz

**File**: `/lib/firmware/overlays/100khz-i2c.dtbo`  
**Recipe**: `picocalc-dt-overlays`

Reduces the I2C2 bus clock from 400 kHz to 100 kHz.

## How Overlays Work

Device tree overlays in Calculinux use the upstream kernel ConfigFS interface (`drivers/of/configfs`), providing a standardized way to load and unload device tree fragments at runtime without requiring external modules.

### Loading an Overlay

```bash
# 1. Create overlay directory
mkdir -p /sys/kernel/config/device-tree/overlays/<overlay-name>

# 2. Load the compiled overlay
cat /lib/firmware/overlays/<overlay-name>.dtbo > /sys/kernel/config/device-tree/overlays/<overlay-name>/dtbo

# 3. Activate the overlay
echo 1 > /sys/kernel/config/device-tree/overlays/<overlay-name>/status
```

### Unloading an Overlay

```bash
# 1. Deactivate
echo 0 > /sys/kernel/config/device-tree/overlays/<overlay-name>/status

# 2. Remove directory
rmdir /sys/kernel/config/device-tree/overlays/<overlay-name>
```

### Making Overlays Persistent

Overlays loaded via ConfigFS don't persist across reboots. To load them automatically, create a systemd service (see [DS3231-RTC.md](DS3231-RTC.md) for an example).

## Creating New Overlays

### 1. Add Overlay Source to picocalc-drivers Repository

Create a `.dts` file in the [picocalc-drivers](https://github.com/Calculinux/picocalc-drivers) repository:

```dts
/dts-v1/;
/plugin/;

/* Your overlay content */

&i2c2 {
    status = "okay";
    
    my_device: device@addr {
        compatible = "vendor,device";
        reg = <0xaddr>;
    };
};
```

### 2. Create a Yocto Recipe

Create a recipe in `meta-calculinux-distro/recipes-bsp/drivers/` like `picocalc-<device>-overlay_1.0.bb`:

```bitbake
SUMMARY = "Device tree overlay for <device>"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"
DEPENDS = "dtc-native"

do_compile() {
    dtc -@ -I dts -O dtb -o ${B}/<overlay-name>.dtbo ${S}/<overlay-source>.dts
}

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/overlays
    install -m 0644 ${B}/<overlay-name>.dtbo ${D}${nonarch_base_libdir}/firmware/overlays/
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/overlays/<overlay-name>.dtbo"
PACKAGES = "${PN}"
```

### 3. Add to Image

Update `kas-luckfox-lyra-bundle.yaml` to include the overlay in `PICOCALC_DRIVERS`:

```yaml
PICOCALC_DRIVERS = "\
  picocalc-drivers-lcd-drm \
  picocalc-drivers-snd-pwm \
  picocalc-drivers-snd-softpwm \
  picocalc-drivers-mfd \
  picocalc-<device>-overlay \
"
```

### 4. Update picocalc-drivers SRCREV

After committing to picocalc-drivers, update the commit hash in `picocalc-drivers-source.inc`:

```bitbake
SRCREV = "<new-commit-hash>"
```

## Common I2C Buses

The RK3506 on Luckfox Lyra has the following I2C buses available:

- **I2C2**: Used for expansion (e.g., DS3231 RTC)
  - SCL: GPIO pin IO4 (`rm_io4_i2c2_scl`)
  - SDA: GPIO pin IO5 (`rm_io5_i2c2_sda`)

Check the pinctrl configuration in device tree files for other available I2C buses.

## Kernel Support

The ConfigFS device tree interface is enabled via these kernel configs:

- `CONFIG_OF_CONFIGFS=y`
- `CONFIG_OF_OVERLAY=y`

These are enabled in the base kernel configuration for Calculinux.

## References

- [Linux Kernel ConfigFS Device Tree Documentation](https://www.kernel.org/doc/html/latest/devicetree/overlay-notes.html)
- [picocalc-drivers Repository](https://github.com/Calculinux/picocalc-drivers)
- Kernel patch: `meta-picocalc-bsp-rockchip/recipes-kernel/linux/files/0001-of-configfs-overlay-interface.patch`
