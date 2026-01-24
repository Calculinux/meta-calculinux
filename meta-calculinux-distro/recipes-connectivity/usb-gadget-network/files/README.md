# USB Gadget Network - Host Setup

This package configures the PicoCalc device to act as a USB network device, allowing direct network connectivity between the device and a host computer.

## Device Configuration

The device is configured with:
- **Device IP**: 192.168.7.2
- **Network**: 192.168.7.0/24
- **Interface**: usb0

The gadget provides two configurations:
1. **RNDIS** (for Windows)
2. **CDC-Ether/ECM** (for Linux/macOS)

## Host Computer Setup

### Linux Host

1. When you connect the PicoCalc via USB, a new network interface should appear (typically `usb0`, `enp0s20u2`, or similar).

2. Configure the host interface:
   ```bash
   sudo ip addr add 192.168.7.1/24 dev usb0
   sudo ip link set usb0 up
   ```

3. Verify connectivity:
   ```bash
   ping 192.168.7.2
   ```

4. SSH into the device:
   ```bash
   ssh pico@192.168.7.2
   ```

#### Automatic Configuration (NetworkManager)

Create `/etc/NetworkManager/system-connections/usb-picocalc.nmconnection`:

```ini
[connection]
id=USB PicoCalc
type=ethernet
interface-name=usb0

[ethernet]

[ipv4]
method=manual
address1=192.168.7.1/24

[ipv6]
method=link-local
```

Then:
```bash
sudo chmod 600 /etc/NetworkManager/system-connections/usb-picocalc.nmconnection
sudo nmcli connection reload
```

#### Automatic Configuration (systemd-networkd)

Create `/etc/systemd/network/50-usb-picocalc.network`:

```ini
[Match]
Name=usb0

[Network]
Address=192.168.7.1/24
```

Then:
```bash
sudo systemctl restart systemd-networkd
```

### macOS Host

1. The device should appear as a CDC-Ether device.

2. Open System Preferences → Network

3. The USB device should appear in the interface list. Configure it with:
   - Configure IPv4: Manually
   - IP Address: 192.168.7.1
   - Subnet Mask: 255.255.255.0

4. Test connectivity:
   ```bash
   ping 192.168.7.2
   ssh pico@192.168.7.2
   ```

### Windows Host

1. When you connect the device, Windows should detect it as an RNDIS device.

2. Install RNDIS drivers if prompted (Windows 10/11 usually has them built-in).

3. Open Network Connections, find the RNDIS/Ethernet Gadget device.

4. Configure IPv4 properties:
   - IP Address: 192.168.7.1
   - Subnet Mask: 255.255.255.0

5. Test connectivity:
   ```cmd
   ping 192.168.7.2
   ssh pico@192.168.7.2
   ```

## Internet Sharing

To share your host's internet connection with the PicoCalc:

### Linux

```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Set up NAT (replace eth0 with your internet-connected interface)
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i usb0 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o usb0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

On the PicoCalc, add a default route:
```bash
sudo ip route add default via 192.168.7.1
```

### macOS

1. System Preferences → Sharing
2. Select "Internet Sharing"
3. Share from: (your internet connection, e.g., Wi-Fi)
4. To computers using: (check the USB Ethernet device)

### Windows

1. Open Network Connections
2. Right-click your internet-connected adapter → Properties
3. Go to Sharing tab
4. Enable "Allow other network users to connect through this computer's Internet connection"
5. Select the USB RNDIS device from the dropdown

## Troubleshooting

### Device not appearing

Check if the USB gadget service is running on the PicoCalc:
```bash
systemctl status usb-gadget-network
```

Restart if needed:
```bash
systemctl restart usb-gadget-network
```

### Cannot ping device

1. Check cable connection
2. Verify IP configuration on both sides:
   - Host: should have 192.168.7.1
   - Device: should have 192.168.7.2
3. Check firewall rules on host

### Module loading errors

The service automatically loads required kernel modules:
- libcomposite
- usb_f_rndis
- usb_f_ecm
- dwc2

Check module status:
```bash
lsmod | grep -E 'libcomposite|rndis|ecm|dwc2'
```

## Advanced Configuration

### Changing IP Addresses

To use a different IP range, edit:
- `/usr/bin/usb-gadget-network.sh` - Change the IP in the script
- `/lib/systemd/network/usb0.network` - Update the Address line

Then restart the service:
```bash
systemctl restart usb-gadget-network
```

### MAC Addresses

The device uses fixed MAC addresses:
- Device: 44:65:76:69:63:65
- Host: 48:6f:73:74:50:43

These can be changed in `/usr/bin/usb-gadget-network.sh`.
