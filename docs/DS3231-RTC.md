# DS3231 Real-Time Clock (RTC) Support

Calculinux includes support for the DS3231 I2C Real-Time Clock module via a device tree overlay.

## Hardware Connection

The DS3231 module connects to **I2C bus 2** on the PicoCalc:

- **VCC**: 3.3V power
- **GND**: Ground
- **SDA**: I2C2 Data (GPIO pin IO5)
- **SCL**: I2C2 Clock (GPIO pin IO4)
- **SQW/INT** (Optional): Interrupt for alarms - can be connected to a GPIO pin

The default I2C address for DS3231 is **0x68**.

## Enabling the DS3231 Overlay

The compiled overlay is installed to `/lib/firmware/overlays/ds3231-rtc.dtbo`.

### Method 1: Runtime via ConfigFS (Temporary)

To enable the DS3231 RTC at runtime (will not persist across reboots):

```bash
# Create overlay directory
mkdir -p /sys/kernel/config/device-tree/overlays/ds3231

# Load the overlay
cat /lib/firmware/overlays/ds3231-rtc.dtbo > /sys/kernel/config/device-tree/overlays/ds3231/dtbo

# Apply the overlay
echo 1 > /sys/kernel/config/device-tree/overlays/ds3231/status
```

To remove the overlay:

```bash
echo 0 > /sys/kernel/config/device-tree/overlays/ds3231/status
rmdir /sys/kernel/config/device-tree/overlays/ds3231
```

### Method 2: Systemd Service (Persistent)

To automatically load the overlay at boot, create a systemd service:

```bash
cat > /etc/systemd/system/ds3231-rtc.service << 'EOF'
[Unit]
Description=Load DS3231 RTC device tree overlay
After=sys-kernel-config.mount
Requires=sys-kernel-config.mount

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'mkdir -p /sys/kernel/config/device-tree/overlays/ds3231 && \
  cat /lib/firmware/overlays/ds3231-rtc.dtbo > /sys/kernel/config/device-tree/overlays/ds3231/dtbo && \
  echo 1 > /sys/kernel/config/device-tree/overlays/ds3231/status'
ExecStop=/bin/sh -c 'echo 0 > /sys/kernel/config/device-tree/overlays/ds3231/status; \
  rmdir /sys/kernel/config/device-tree/overlays/ds3231'

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ds3231-rtc.service
systemctl start ds3231-rtc.service
```

## Verifying the RTC

After loading the overlay, verify the DS3231 is detected:

```bash
# Check I2C device
i2cdetect -y 2

# Check RTC device node
ls -l /dev/rtc*

# Check kernel messages
dmesg | grep -i rtc
```

You should see the device at address 0x68 and `/dev/rtc1` should appear (assuming the SoC has a built-in RTC at `/dev/rtc0`).

## Using the DS3231 RTC

### Read the current time

```bash
hwclock -r -f /dev/rtc1
```

### Set the RTC from system time

```bash
hwclock -w -f /dev/rtc1
```

### Set system time from RTC

```bash
hwclock -s -f /dev/rtc1
```

### Make DS3231 the system RTC

To make the DS3231 the default RTC device, create a udev rule:

```bash
cat > /etc/udev/rules.d/50-rtc.rules << 'EOF'
# Make DS3231 the default RTC
KERNEL=="rtc1", SUBSYSTEM=="rtc", SYMLINK+="rtc", OPTIONS+="link_priority=10"
EOF

udevadm control --reload-rules
```

## Troubleshooting

### I2C Device Not Found

Check I2C bus and device connections:

```bash
i2cdetect -y 2
```

If you don't see device at 0x68:
- Verify hardware connections
- Check 3.3V power to module
- Verify SDA/SCL are connected to correct GPIO pins

### RTC Driver Not Loading

Check kernel messages for errors:

```bash
dmesg | grep -i "ds3231\|rtc"
```

Verify the overlay is loaded:

```bash
ls /sys/kernel/config/device-tree/overlays/
cat /sys/kernel/config/device-tree/overlays/ds3231/status
```

### Using Interrupt Pin for Alarms

If you want to use the DS3231's alarm functionality with interrupts, edit the overlay source file and uncomment the interrupt configuration:

```dts
interrupt-parent = <&gpio0>;
interrupts = <RK_PA0 IRQ_TYPE_EDGE_FALLING>;
```

Change `RK_PA0` to match your actual GPIO connection, then recompile the overlay.

## References

- [DS3231 Datasheet](https://datasheets.maximintegrated.com/en/ds/DS3231.pdf)
- [Linux RTC Documentation](https://www.kernel.org/doc/html/latest/admin-guide/rtc.html)
- Device tree overlay source: `picocalc-drivers/ds3231-rtc-overlay.dts`
