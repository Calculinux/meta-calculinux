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
GPIO3_B3 (Pin 29)  →  MOSI
GPIO3_B4 (Pin 28)  →  MISO
GPIO3_B6 (Pin 26)  →  DIO1
GPIO3_B5 (Pin 27)  →  BUSY
GPIO1_D0 (Pin 115) →  DIO2
GND                →  CS + GND
3.3V               →  VCC + DIO2_RF_SWITCH
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

The config file has been updated:
- **File**: `meta-meshtastic/recipes-connectivity/meshtasticd/files/config.d/luckfox_pico-lora-rfsw-no_tcxo.yaml`
- **SPI Method**: GPIO bitbang (not hardware SPI)
- **Speed**: 2 MHz (adequate for LoRA)
- **RF Switch**: Automatic (DIO2_AS_RF_SWITCH: true)

### GPIO Mapping (for reference)

The GPIO numbers in the config use `gpiochip: 1` with 32 subtracted:

| Pin | Logical GPIO | Meshtastic ID | Function |
|-----|--------------|----------------|----------|
| GPIO3_B2 | 106 | 74 (CLK-32) | SPI Clock |
| GPIO3_B3 | 107 | 75 (MOSI-32) | SPI MOSI |
| GPIO3_B4 | 108 | 76 (MISO-32) | SPI MISO |
| GPIO3_B6 | 110 | 78 (IRQ-32) | DIO1 Interrupt |
| GPIO3_B5 | 109 | 77 (BUSY-32) | Busy Status |
| GPIO1_D0 | 64 | 32 (DIO2-32) | RF Switch |

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
- Add GPIO3_B2 mapping and change meshtastic config `CS: 106`

### 5. Power and Ground

- Connect **VCC** to any **3.3V test pad**
- Connect **GND** to any **GND test pad** (multiple connections recommended)
- Add **10µF decoupling capacitor** near VCC pin

### 6. RF Connections

- **Antenna**: Connect to ANT connector
- **RXEN**: Tie to GND (RX default)
- **TXEN**: Tie to GND (or control via GPIO if desired)
- **DIO2**: For automatic RF switching, connect to GPIO1_D0

## Software Setup

### 1. Build with Meshtastic Support

```bash
cd calculinux-build
./meta-calculinux/kas-container build ./meta-calculinux/kas-luckfox-lyra-bundle.yaml
```

### 2. Deploy Device Tree Overlay

The overlay should be compiled and installed in the image:
```
/lib/firmware/overlays/sx1262-lora.dtbo
```

### 3. Apply Overlay at Runtime (optional)

```bash
ssh pico@192.168.7.2
mkdir -p /sys/kernel/config/device-tree/overlays/sx1262
cat /lib/firmware/overlays/sx1262-lora.dtbo > \
    /sys/kernel/config/device-tree/overlays/sx1262/dtbo
echo 1 > /sys/kernel/config/device-tree/overlays/sx1262/status
```

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

# Verify Meshtastic config
cat /etc/meshtastic/config.d/luckfox_pico-lora-rfsw-no_tcxo.yaml
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
