# USB Host/Gadget Mode Switching

This feature enables the PicoCalc's USB OTG port to switch between **gadget mode** (device) and **host mode** at runtime.

## Overview

The Luckfox Lyra has two USB OTG controllers:
- **usb20_otg0** (main USB-C port): Now supports runtime mode switching between gadget and host
- **usb20_otg1**: Fixed host mode

## Modes

### Gadget Mode (Default)
When in gadget mode, the PicoCalc acts as a USB device providing:
- USB networking (ECM/RNDIS)
- USB serial console (optional)
- ADB over USB (optional)

This is the default mode and is used for connecting the PicoCalc to a host computer.

### Host Mode
When in host mode, the PicoCalc acts as a USB host and can connect to:
- USB flash drives
- USB keyboards
- USB mice
- Other USB peripherals

**Note**: In host mode, USB gadget networking is not available. You'll need alternate connectivity (WiFi, serial console, etc.) to access the device.

## Configuration

Edit `/etc/default/usb-gadget-network` to set the USB mode:

```bash
# USB port mode: "gadget" for USB device mode, "host" for USB host mode
USB_MODE=gadget  # or USB_MODE=host
```

### Switching to Host Mode

1. Connect to your PicoCalc via WiFi or serial console (not USB)
2. Edit the configuration:
   ```bash
   sudo nano /etc/default/usb-gadget-network
   # Change: USB_MODE=host
   ```
3. Restart the USB service:
   ```bash
   sudo systemctl restart usb-gadget-network
   ```
4. The USB port is now in host mode - connect your USB devices!

### Switching Back to Gadget Mode

Since you won't have USB network access in host mode, you'll need to connect via:
- WiFi (if configured)
- Hardware serial console
- USB serial console (if you enabled it before switching to host mode)

Then:
1. Edit the configuration:
   ```bash
   sudo nano /etc/default/usb-gadget-network
   # Change: USB_MODE=gadget
   ```
2. Restart the USB service:
   ```bash
   sudo systemctl restart usb-gadget-network
   ```
3. Reconnect your USB cable to the host computer

## Accessing USB Storage in Host Mode

When a USB storage device is connected in host mode, it will appear as `/dev/sda` (or similar):

```bash
# List detected USB devices
lsusb

# Check kernel messages for USB storage
dmesg | grep -i usb

# Mount USB drive (example)
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb

# Unmount when done
sudo umount /mnt/usb
```

## Implementation Details

### Device Tree Changes
- Changed `dr_mode` from `"peripheral"` to `"otg"` in `rk3506-luckfox-lyra.dtsi`
- This enables the hardware OTG capability

### Kernel Configuration
Added USB host support:
- `CONFIG_USB_DWC2_HOST=y` - DWC2 host mode support
- `CONFIG_USB_DWC2_DUAL_ROLE=y` - Dual-role operation (OTG)
- `CONFIG_USB_STORAGE=m` - USB mass storage support

### Script Logic
The `usb-gadget-network.sh` script now:
- Checks `USB_MODE` from `/etc/default/usb-gadget-network`
- In gadget mode: Sets up ConfigFS gadget as before
- In host mode: Leaves the DWC2 controller unbound from gadget, allowing it to operate as a host

## Troubleshooting

### USB device not detected in host mode

Check that you're in host mode:
```bash
grep USB_MODE /etc/default/usb-gadget-network
# Should show: USB_MODE=host
```

Check USB controller status:
```bash
# No gadget should be configured
ls /sys/kernel/config/usb_gadget/
# Should be empty or g1 should not exist

# Check for USB devices
lsusb
dmesg | tail -20
```

### Lost connection after switching to host mode

This is expected - USB gadget networking is disabled in host mode. Use WiFi or serial console to reconnect.

### Can't switch back to gadget mode

You need alternate access (WiFi, serial) to change the configuration and restart the service. If you don't have alternate access:
1. Remove the SD card
2. Mount it on another computer
3. Edit `/etc/default/usb-gadget-network` on the overlay partition
4. Change `USB_MODE=gadget`
5. Remount and boot

## See Also

- [USB Networking Documentation](docs/user-guide/usb-networking.md)
- USB gadget recipe: `meta-calculinux-distro/recipes-connectivity/usb-gadget-network/`
