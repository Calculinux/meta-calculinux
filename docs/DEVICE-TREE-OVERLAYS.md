# Device Tree Overlays for Calculinux

Calculinux currently supports runtime loading of device tree overlays via ConfigFS.

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

## Runtime Overlay Loading (ConfigFS)

Device tree overlays can also be loaded after boot using the kernel's ConfigFS interface, providing flexibility for development and testing.

### How Overlays Work

Device tree overlays use the upstream kernel ConfigFS interface (`drivers/of/configfs`), providing a standardized way to load and unload device tree fragments at runtime without requiring external modules.

### Loading an Overlay at Runtime

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

Create a `.dts` file in the [picocalc-drivers](https://github.com/Calculinux/picocalc-drivers) repository under `devicetree-overlays/`:

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

**Naming Convention**: `<purpose>-overlay.dts` (e.g., `custom-device-overlay.dts`)

The compiled output will be `<purpose>.dtbo` (e.g., `custom-device.dtbo`)

### 2. Update picocalc-dt-overlays Recipe (Optional)

If adding to the official distribution, the consolidated `picocalc-dt-overlays` recipe will automatically compile and install your `.dts` file. Just update `picocalc-drivers-source.inc` with the new commit hash:

```bitbake
SRCREV = "<new-commit-hash>"
```

For one-off overlays not in the main build, you can manually compile:

```bash
# On device or build host with dtc installed
dtc -@ -I dts -O dtb -o my-overlay.dtbo my-overlay-overlay.dts
cp my-overlay.dtbo /lib/firmware/overlays/
```

### 3. Testing Your Overlay

**Option A: Boot-Time Loading (Easier)**

Add the overlay name (or absolute path) to `/etc/device-tree-overlays.conf`,
copy the `.dtbo` to `/lib/firmware/overlays/`, reboot, and check boot logs:

```bash
ssh pico@192.168.7.2 dmesg | grep -i overlay
```

**Option B: Runtime Loading (Quick Iteration)**

Test with ConfigFS before committing to the image:

```bash
mkdir -p /sys/kernel/config/device-tree/overlays/my-overlay
cat /lib/firmware/overlays/my-overlay.dtbo > /sys/kernel/config/device-tree/overlays/my-overlay/dtbo
echo 1 > /sys/kernel/config/device-tree/overlays/my-overlay/status
```

Check dmesg for any errors:

```bash
dmesg | tail -20
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
