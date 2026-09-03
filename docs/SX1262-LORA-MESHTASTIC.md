# Waveshare SX1262HF LoRA Module for PicoCalc + Meshtastic

## Hardware Setup

### Module: Waveshare Core1262-868M SX1262HF
- **Frequency**: 868 MHz (also available: 433 MHz, 915 MHz)
- **Power**: 3.3V @ ~50mA active
- **SPI Interface**: Up to 10 MHz (will use 2 MHz bitbang)
- **Datasheet**: https://www.waveshare.com/wiki/Core1262-868M

### Pin Connections

```
PicoCalc Lyra              SX1262 Module
────────────────────────────────────────
GPIO3_B2 (Pin 30)  →  CLK
GPIO3_B5 (Pin 27)  →  MOSI
GPIO3_A6           →  MISO
GPIO3_B6 (Pin 26)  →  DIO1
GPIO1_D0 (Pin 115) →  BUSY
GND                →  GND
GND                →  CS (tie CS low; or a free GPIO if you want software CS)
3.3V               →  VCC + RESET pullup
```

### RESET Pin Handling

**The SX1262 has an active-low RESET pin, and you're tying it HIGH permanently.**

This is a valid approach because:
1. The module has internal pull-ups on RESET
2. Meshtastic doesn't need to perform hardware reset on startup
3. Software initialization resets the module state via SPI commands
4. It saves one GPIO pin

**Circuit:**
```
3.3V ──[10kΩ]── RESET pin (SX1262)
```

The 10kΩ resistor is optional but recommended to limit current if the pin is accidentally driven low.

### RF Switch Control

The SX1262 module includes automatic RF switching. Configuration:
- **DIO2_AS_RF_SWITCH: true** in Meshtastic config enables internal control
- **DIO2** pin controls the switch mode (optional hardware control)
- Tie **RXEN** and **TXEN** to GND for default RX mode, or control via DIO2

## Bitbang SPI Performance

### Why Software SPI Works

| Metric | Value | Impact |
|--------|-------|--------|
| ARM CPU Clock | 100 MHz | Fast GPIO toggle |
| Target SPI Speed | 2 MHz | Bitbang capable |
| LoRA Air Interface | ~1 second | SPI not the bottleneck |
| Data Rate | 50 kbps max | Plenty of margin |

**Calculation:** At 100 MHz CPU, minimum GPIO toggle time is ~10 ns. A 2 MHz SPI clock needs 250 ns per bit-period, which is achievable with ample headroom for software overhead.

### Performance Expectations

- **SPI Throughput**: ~2 Mbps (bitbang at 2 MHz, 1 data bit per clock)
- **Typical SPI Transaction**: 50-100 bytes @ 2 MHz = 200-400 microseconds
- **Meshtastic Operation**: Fully functional, no noticeable lag
- **Real-world Bottleneck**: LoRA air interface (1-10 second packet times)

## Meshtastic Configuration

Shipped Meshtastic samples (Luckfox Pico modules, not this PicoCalc wiring) live in
`meta-meshtastic/recipes-connectivity/meshtasticd/files/config.d/` and install to
`/etc/meshtasticd/available.d/`. Enable a sample by linking it into `/etc/meshtasticd/config.d/`.

For the Waveshare wiring above, copy a sample and edit CS/IRQ/Busy/gpiochip (or write a new
YAML) so it matches the table below. With CS tied to GND, set `CS: -1`.
- **SPI Method**: GPIO bitbang (`spidev2.0` from the `sx1262-lora` overlay)
- **Speed**: 2 MHz
- **RF Switch**: Automatic (`DIO2_AS_RF_SWITCH: true`); CS and RESET tied (config `-1`)

### GPIO Mapping (for the wiring above)

`gpiochip` 3 is bank 3; line = group*8+X (A=0, B=1, …). Busy is on gpiochip 1.

| Pin | yaml | Function |
|-----|------|----------|
| GPIO3_B2 | gpiochip 3, CLK: 10 | SPI Clock |
| GPIO3_B5 | gpiochip 3, MOSI: 13 | SPI MOSI |
| GPIO3_A6 | gpiochip 3, MISO: 6 | SPI MISO |
| GPIO3_B6 | gpiochip 3, IRQ: 14 | DIO1 |
| GPIO1_D0 | gpiochip 1, Busy line: 24 | Busy |

## Assembly Instructions

### 1. Prepare the Module

```bash
# Check module orientation - antenna connector should face outward
# Verify all pins are straight and not bent
```

### 2. Solder Test Pad Connections

Wire the 6 signal pins to the test pads:
- Use 24-28 AWG wire for reliability
- Keep traces short (under 5cm if possible)
- Twist CLK + MOSI together (reduce EMI)
- Separate MISO from CLK/MOSI if possible

### 3. RESET Pullup (Important!)

On the SX1262 module, locate the RESET pin and connect:
```
[RESET pin] ──[10kΩ]── [3.3V test pad]
           ││
           └─ Leave floating or this risks brownouts
```

### 4. Chip Select

**Option A (Recommended):** Permanently tie CS to GND
```
[CS pin] ── [GND test pad]  (solder directly)
```

**Option B:** Use GPIO (uses extra pin)
- If you want CS controlled by software later, don't ground it
- Wire CS to a free GPIO and set `CS:` in the YAML (do not reuse CLK GPIO3_B2)

### 5. Power and Ground

- Connect **VCC** to any **3.3V test pad**
- Connect **GND** to any **GND test pad** (multiple connections recommended)
- Add **10µF decoupling capacitor** near VCC pin

### 6. RF Connections

- **Antenna**: Connect to ANT connector
- **RXEN**: Tie to GND (RX default)
- **TXEN**: Tie to GND (or control via GPIO if desired)
- **DIO2**: Module-internal RF switch (`DIO2_AS_RF_SWITCH`); GPIO1_D0 is Busy, not DIO2

## Software Setup

### 1. Build with Meshtastic Support

```bash
cd calculinux-build
./meta-calculinux/kas-container build ./meta-calculinux/kas-luckfox-lyra-bundle.yaml
```

### 2. Deploy Device Tree Overlay

The overlay should be compiled and installed in the image:
```
/boot/devicetree/sx1262-lora.dtbo
```

### 3. Enable Overlay (default: merged for next boot)

Add `sx1262-lora` to `/etc/device-tree-overlays.conf`, then reboot. Calculinux will merge overlays
into the boot DTB/FIT for the **next boot**.

### 4. Apply Overlay at Runtime (developer option)

```bash
ssh pico@192.168.7.2
mkdir -p /sys/kernel/config/device-tree/overlays/sx1262
cat /boot/devicetree/sx1262-lora.dtbo > \
    /sys/kernel/config/device-tree/overlays/sx1262/dtbo
cat /sys/kernel/config/device-tree/overlays/sx1262/status   # expect: applied
```

If you see `rockchip-pinctrl ... unable to find group for node sx1262-pins`, use the merged-boot workflow
and reboot, or use the runtime-friendly overlay `sx1262-lora-runtime.dtbo`.

### 4. Verify Meshtastic Operation

```bash
# Check meshtasticd is running
systemctl status meshtasticd

# Verify LoRA module is detected
journalctl -u meshtasticd -f | grep -i "lora\|sx1262\|spi"

# Check for packet reception
meshtastic --info
```

## Troubleshooting

### Module Not Detected

```bash
# Check kernel device tree
dtc -I fs /sys/firmware/devicetree/base > /tmp/dt.dts
grep -i "sx1262\|lora" /tmp/dt.dts

# Check GPIO pins are exported
ls -la /sys/class/gpio/ | grep gpio[0-9]

# Verify Meshtastic config (edit a sample from available.d to match this wiring)
ls /etc/meshtasticd/available.d/
ls /etc/meshtasticd/config.d/
```

### SPI Communication Issues

```bash
# Test SPI bitbang manually (if pins are accessible)
cd /sys/class/gpio

# Export CLK pin
echo 106 > export

# Toggle CLK to verify GPIO is functional
echo out > gpio106/direction
echo 1 > gpio106/value
echo 0 > gpio106/value

# If this works, SPI bitbang should work
```

### Intermittent Packet Loss

- **Reduce SPI speed** (change spiSpeed to 1000000 in config)
- **Check wiring quality** (solder joints, wire gauge)
- **Improve antenna placement** (elevate, away from ground plane)
- **Add shielding** if needed (wrap module in foil, keep away from power traces)

### RESET Pin Issues

If the module fails to initialize:
1. Verify RESET pin is tied to 3.3V (not floating)
2. Check for shorts to GND
3. Measure voltage on RESET (should be ~3.3V stable)
4. Try removing the 10kΩ resistor (use direct wire if power is stable)

## References

- **Waveshare Documentation**: https://www.waveshare.com/wiki/Core1262-868M
- **SX1262 Datasheet**: Contact Semtech or check Waveshare site
- **Meshtastic Docs**: https://meshtastic.org/
- **GPIO Bitbang Performance**: Standard for embedded systems at 2 MHz
