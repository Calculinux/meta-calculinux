# Device Tree Overlays for Calculinux

Calculinux supports device tree overlays in two ways:

- **Default (persistent)**: merge overlays into the boot DTB/FIT for the **next boot**
- **Developer option (non-persistent)**: apply overlays at runtime via ConfigFS

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

### PCM5102A I2S DAC Module

**File**: `/boot/devicetree/pcm5102a-i2s.dtbo`  
**Recipe**: `picocalc-dt-overlays`  
**Documentation**: [PCM5102A-I2S-DAC.md](PCM5102A-I2S-DAC.md)

Enables I2S audio output via the PCM5102A DAC module on RMII1 test pads. Provides high-quality audio output for the PicoCalc.

### SX1262 LoRA Module (Meshtastic)

**File**: `/boot/devicetree/sx1262-lora.dtbo`  
**Recipe**: `picocalc-dt-overlays`  
**Documentation**: [SX1262-LORA-MESHTASTIC.md](SX1262-LORA-MESHTASTIC.md)

Configures GPIO pins for software SPI communication with the Waveshare SX1262 LoRA transceiver on RMII1 test pads. Enables Meshtastic mesh networking capabilities.

### u-blox NEO-M8N GPS Module

**File**: `/boot/devicetree/neo-m8n-gps.dtbo`  
**Recipe**: `picocalc-dt-overlays`  
**Documentation**: [NEO-M8N-GPS.md](NEO-M8N-GPS.md)

Enables UART5 for communication with the u-blox NEO-M8N GPS module on RMII1 test pads. Compatible with gpsd and standard NMEA applications. Can be used alongside the SX1262 LoRA module for GPS-equipped Meshtastic nodes.

## Default (Persistent) Behavior: Merge for Next Boot

List overlays in `/etc/device-tree-overlays.conf`. `merge-dt-overlays-boot` runs at boot and
when that config (or `/etc/devicetree/`) changes, and writes
`/data/fit/zboot_merged_<rauc-slot>.img` for the **current** RAUC slot only.

U-Boot loads that slot's FIT, then `/boot/zboot_merged.img` on the same root, then
unmerged `zboot.img`. It never boots the other slot's FIT (that FIT has the other
slot's kernel). A RAUC install deletes the target slot's merged FIT so the first
boot after update uses `/boot/zboot_merged.img`.

Notes:

- **Changes require a reboot** to take effect.
- The image does not enable hardware overlays by default; add names such as `sx1262-lora` to the config.
- Overlays are resolved from `/etc/devicetree/` first (user overrides), then `/boot/devicetree/` (image-provided).

## Runtime Overlay Loading (ConfigFS) (Developer Option)

Device tree overlays can also be loaded after boot using the kernel's ConfigFS interface, providing flexibility for development and testing.

### How Overlays Work

Device tree overlays use the upstream kernel ConfigFS interface (`drivers/of/configfs`), providing a standardized way to load and unload device tree fragments at runtime without requiring external modules.

### Loading an Overlay at Runtime

```bash
# 1. Create overlay directory
mkdir -p /sys/kernel/config/device-tree/overlays/<overlay-name>

# 2. Write the compiled overlay (kernel applies on this write; status is read-only)
cat /boot/devicetree/<overlay-name>.dtbo > /sys/kernel/config/device-tree/overlays/<overlay-name>/dtbo

# 3. Confirm it applied
cat /sys/kernel/config/device-tree/overlays/<overlay-name>/status   # expect: applied
```

### Unloading an Overlay

```bash
rmdir /sys/kernel/config/device-tree/overlays/<overlay-name>
```

### Making Overlays Persistent

Overlays loaded via ConfigFS don't persist across reboots. For persistent behavior, use `/etc/device-tree-overlays.conf`
and reboot (merged-boot behavior).

## Creating New Overlays

### 1. Add Overlay Source to picocalc-drivers Repository

Create a `.dts` file in the [picocalc-drivers](https://github.com/Calculinux/picocalc-drivers) repository under `overlays/` (generic) or `luckfox-lyra/overlays/` (Lyra-specific):

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
dtc -@ -I dts -O dtb -o custom-device.dtbo custom-device-overlay.dts
cp custom-device.dtbo /etc/devicetree/
```

### 3. Testing Your Overlay

**Option A: Boot-Time Loading (Easier)**

Add the overlay name (or absolute path) to `/etc/device-tree-overlays.conf`,
copy the `.dtbo` to `/etc/devicetree/` (or `/boot/devicetree/`), reboot, and check boot logs:

```bash
ssh pico@192.168.7.2 dmesg | grep -i overlay
```

**Option B: Runtime Loading (Quick Iteration)**

Test with ConfigFS before committing to the image:

```bash
mkdir -p /sys/kernel/config/device-tree/overlays/custom-device
cat /etc/devicetree/custom-device.dtbo > /sys/kernel/config/device-tree/overlays/custom-device/dtbo
cat /sys/kernel/config/device-tree/overlays/custom-device/status   # expect: applied
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
