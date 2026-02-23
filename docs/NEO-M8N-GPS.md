# u-blox NEO-M8N GPS Module Support

Calculinux includes support for the u-blox NEO-M8N GPS module via a device tree overlay that enables UART5 communication.

## Hardware Connection

The NEO-M8N module connects to **UART5** on the PicoCalc RMII1 test pads:

- **VCC**: 3.3V power
- **GND**: Ground
- **TX**: UART5_RX (GPIO3_B3, Pin 29) - GPS transmits data to PicoCalc
- **RX**: UART5_TX (GPIO3_B4, Pin 28) - PicoCalc transmits commands to GPS
- **PPS** (Optional): Pulse-per-second signal for high-precision time sync - can be connected to a GPIO pin

> **Note**: The NEO-M8N TX connects to the PicoCalc RX, and NEO-M8N RX connects to PicoCalc TX.

The NEO-M8N defaults to **9600 baud** but can be configured up to 230400 baud using u-center or NMEA commands.

## Enabling the NEO-M8N Overlay

The compiled overlay is installed to `/lib/firmware/overlays/neo-m8n-gps.dtbo`.

### Method 1: Runtime via ConfigFS (Temporary)

To enable the NEO-M8N GPS at runtime (will not persist across reboots):

```bash
# Create overlay directory
mkdir -p /sys/kernel/config/device-tree/overlays/neo-m8n

# Load the overlay
cat /lib/firmware/overlays/neo-m8n-gps.dtbo > /sys/kernel/config/device-tree/overlays/neo-m8n/dtbo

# Apply the overlay
echo 1 > /sys/kernel/config/device-tree/overlays/neo-m8n/status
```

To remove the overlay:

```bash
echo 0 > /sys/kernel/config/device-tree/overlays/neo-m8n/status
rmdir /sys/kernel/config/device-tree/overlays/neo-m8n
```

### Method 2: Systemd Service (Persistent)

To automatically load the overlay at boot, create a systemd service:

```bash
cat > /etc/systemd/system/neo-m8n-gps.service << 'EOF'
[Unit]
Description=Load NEO-M8N GPS device tree overlay
After=sys-kernel-config.mount
Requires=sys-kernel-config.mount

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'mkdir -p /sys/kernel/config/device-tree/overlays/neo-m8n && \
  cat /lib/firmware/overlays/neo-m8n-gps.dtbo > /sys/kernel/config/device-tree/overlays/neo-m8n/dtbo && \
  echo 1 > /sys/kernel/config/device-tree/overlays/neo-m8n/status'
ExecStop=/bin/sh -c 'echo 0 > /sys/kernel/config/device-tree/overlays/neo-m8n/status; \
  rmdir /sys/kernel/config/device-tree/overlays/neo-m8n'

[Install]
WantedBy=multi-user.target
EOF

systemctl enable neo-m8n-gps.service
systemctl start neo-m8n-gps.service
```

## Verifying the GPS Connection

After loading the overlay, verify UART5 is available:

```bash
# Check serial device
ls -l /dev/ttyS5

# Check kernel messages
dmesg | grep uart5
dmesg | grep ttyS5
```

## Reading GPS Data

### Raw NMEA Sentences

To read raw NMEA sentences from the GPS:

```bash
# Read continuous GPS data
cat /dev/ttyS5

# Read with stty configuration
stty -F /dev/ttyS5 9600 raw
cat /dev/ttyS5
```

Example NMEA output:
```
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
$GPGSA,A,3,04,05,,09,12,,,24,,,,,2.5,1.3,2.1*39
$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
```

### Using gpsd

Install and configure `gpsd` for easier GPS access:

```bash
# Install gpsd (if not already installed)
opkg update
opkg install gpsd gpsd-clients

# Start gpsd
gpsd /dev/ttyS5 -F /var/run/gpsd.sock

# Monitor GPS status
gpsmon /dev/ttyS5

# Or use cgps for a simpler display
cgps
```

### Using gpsmon/cgps without gpsd daemon

You can directly monitor the GPS without running the gpsd daemon:

```bash
gpsmon /dev/ttyS5
```

## GPS Applications

### Time Synchronization

Use the GPS for NTP time synchronization:

```bash
# Install gpsd and gpsd-clients
opkg install gpsd gpsd-clients

# Configure chronyd or ntpd to use GPS as a time source
# (Refer to Calculinux time sync documentation)
```

### Location Services

The GPS can be used with applications that support NMEA or gpsd:
- Navigation applications
- Geocaching tools
- Location logging
- Meshtastic with GPS positioning (when used alongside LoRA module)

## Troubleshooting

### No data from GPS

1. **Check connections**: Ensure TX/RX are not swapped
2. **Check baud rate**: Default is 9600, verify with:
   ```bash
   stty -F /dev/ttyS5
   ```
3. **Check GPS power**: Module requires 3.3V
4. **Wait for satellite fix**: GPS may take 30-60 seconds for first fix (cold start)

### GPS not detected

```bash
# Verify overlay is loaded
ls /sys/kernel/config/device-tree/overlays/neo-m8n/

# Check if UART5 is enabled in device tree
ls -l /dev/ttyS5

# Check kernel messages
dmesg | grep -i uart
```

### Adjusting Baud Rate

To change the GPS baud rate (requires sending UBX configuration commands):

```bash
# Install u-blox u-center or use NMEA commands
# Example NMEA command to set 115200 baud:
echo '$PUBX,41,1,0007,0003,115200,0*18' > /dev/ttyS5

# Then reconfigure the serial port:
stty -F /dev/ttyS5 115200
```

## Hardware Considerations

### Antenna

The NEO-M8N requires an external active or passive GPS antenna:
- **Active antenna**: Requires power (3.3V via module's ANT_PWR)
- **Passive antenna**: No power needed but lower sensitivity

### Power Consumption

- Active mode: ~23 mA @ 3.3V
- Power save mode: ~11 mA (configurable via UBX protocol)
- Backup mode: ~15 µA (requires backup battery on V_BKUP pin)

## Compatibility with LoRA Module

The NEO-M8N GPS overlay is designed to work alongside the SX1262 LoRA module overlay. The LoRA module uses UART5_CTSN and UART5_RTSN pins (which are not needed for GPS), while the GPS uses UART5_TX and UART5_RX.

**Both overlays can be loaded simultaneously** to enable GPS-equipped Meshtastic functionality.

## Device Tree Overlay Source

The overlay source is located in the `picocalc-drivers` repository:
- Path: `devicetree-overlays/neo-m8n-gps-overlay.dts`
- Compiled to: `/lib/firmware/overlays/neo-m8n-gps.dtbo`

## Additional Resources

- [u-blox NEO-M8 Datasheet](https://www.u-blox.com/en/product/neo-m8-series)
- [NMEA Protocol Reference](http://www.gpsinformation.org/dale/nmea.htm)
- [gpsd Documentation](https://gpsd.gitlab.io/gpsd/)
- [u-center Configuration Software](https://www.u-blox.com/en/product/u-center) (Windows only)
