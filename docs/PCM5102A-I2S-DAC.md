# PCM5102A I2S DAC for PicoCalc Audio

## Hardware Shopping List

### PCM5102A DAC Module
**Recommended:** GY-PCM5102 breakout board
- **Price:** ~$1.50-3.00 USD  
- **Where to buy:** AliExpress, eBay
- **Search terms:** "PCM5102 GY-PCM5102", "PCM5102A I2S DAC"
- **Specifications:**
  - 24-bit/192kHz capable
  - Stereo output (Left + Right channels)
  - 3.3V compatible
  - No configuration needed (hardware mode)

## Pin Connections

### Lyra → PCM5102A Wiring

| Lyra Pin | Lyra Signal | Pin Location | PCM5102A Pin | Function |
|----------|-------------|--------------|--------------|----------|
| 33 | GPIO3_A7 (SAI2_SCLK_M0) | RMII1_RXD1 test pad | BCK | Bit Clock |
| 32 | GPIO3_B0 (SAI2_SDO_M0) | RMII1_CLK test pad | DIN | Data Input |
| 31 | GPIO3_B1 (SAI2_LRCK_M0) | RMII1_TXD0 test pad | LCK | Left/Right Clock |
| 26 | GPIO3_B6 (SAI2_MCLK_M0) | RMII1_RXDVCRS test pad | SCK | Master Clock (optional) |
| 3.3V | Power | Any 3.3V pad | VIN/VCC | Power Supply |
| GND | Ground | Any GND pad | GND | Ground |

### PCM5102A Module Configuration

**Required jumpers/connections on GY-PCM5102 module:**
- **FLT** → GND (normal filter latency)
- **DEMP** → GND (de-emphasis off)  
- **XSMT** → 3.3V (soft mute off)
- **FMT** → GND (I2S format)
- **H1L**, **H2L**, **H3L**, **H4L** → All LOW (3.3V system, I2S format)

**Optional:**
- **SCK** (master clock) can be left disconnected - PCM5102A will work fine without it
- If your module doesn't have these jumpers, it likely runs in fixed hardware mode (which is perfect)

### Output Connections

The PCM5102A has stereo line-level outputs:
- **LOUT** → Connect to Left channel of your existing audio circuit (where filtered PWM left goes)
- **ROUT** → Connect to Right channel of your existing audio circuit (where filtered PWM right goes)
- **AGND** → Audio ground reference

**Integration with existing PicoCalc audio:**
- Disconnect or disable the PWM audio signals
- Connect DAC outputs to the same point where the **filtered PWM** signals currently feed
- The DAC output is already analog, so it bypasses the PWM low-pass filter
- Connect directly to the amplifier input or headphone jack

## Software Setup

### 1. Device Tree Overlay
The overlay has been created at:
```
picocalc-drivers/devicetree-overlays/pcm5102a-i2s-overlay.dts
```

### 2. Kernel Configuration
The kernel config fragment has been added:
```
meta-picocalc-bsp-rockchip/recipes-kernel/linux/files/audio-i2s.cfg
```

This enables:
- `CONFIG_SND_SOC_PCM5102A=y` (codec driver)
- `CONFIG_SND_SIMPLE_CARD=y` (simple audio card framework)
- `CONFIG_SND_SOC_ROCKCHIP_SAI=y` (already enabled)

### 3. Build and Deploy
```bash
# From calculinux-build/ directory
./meta-calculinux/kas-container build ./meta-calculinux/kas-luckfox-lyra-bundle.yaml

# Flash updated image to device
# Copy overlay to device: /lib/firmware/overlays/pcm5102a-i2s.dtbo
```

### 4. Apply Overlay at Runtime
```bash
# On the PicoCalc device:
mkdir -p /sys/kernel/config/device-tree/overlays/pcm5102a
cat /lib/firmware/overlays/pcm5102a-i2s.dtbo > \
    /sys/kernel/config/device-tree/overlays/pcm5102a/dtbo
echo 1 > /sys/kernel/config/device-tree/overlays/pcm5102a/status
```

### 5. Verify Audio Device
```bash
# Check sound card appeared
aplay -l

# Test stereo output
speaker-test -D hw:0,0 -c 2 -t sine
```

## Benefits Over PWM Audio

1. **Zero CPU overhead** - Hardware I2S controller handles everything
2. **Much better audio quality** - True 24-bit DAC vs software PWM
3. **No PWM noise** - Clean analog output, no high-frequency carrier
4. **Stereo support** - Left and Right channels properly separated
5. **Standard ALSA interface** - Works with any Linux audio software

## Troubleshooting

### No sound output
- Check all wire connections
- Verify overlay loaded: `ls /sys/kernel/config/device-tree/overlays/`
- Check kernel log: `dmesg | grep -i "pcm5102\|sai2"`
- Verify sound card: `cat /proc/asound/cards`

### Distorted or noisy audio
- Check VCC is stable 3.3V
- Ensure good ground connection
- Verify pin functions are correct (not still configured as GPIO)
- Check format jumpers on PCM5102A module

### One channel missing
- Verify LCK (LRCK) connection
- Check both LOUT and ROUT wiring
- Test with: `speaker-test -D hw:0,0 -c 2 -t wav`

## Technical Notes

### About SAI2_MCLK (Master Clock)
- The PCM5102A can operate without master clock in "slave mode"
- MCLK is typically 256× the sample rate (e.g., 12.288 MHz for 48 kHz audio)
- The Lyra's SAI2 controller can generate MCLK automatically if needed
- For simplest setup, leave MCLK/SCK unconnected initially

### Sample Rates
The SAI2 controller supports:
- 8 kHz to 192 kHz sample rates
- 16-bit, 24-bit, 32-bit sample depths
- I2S, Left-Justified, Right-Justified formats

### Power Consumption
- PCM5102A: ~10mA typical
- Much lower than CPU overhead from software PWM
- Can be powered directly from Lyra 3.3V rail
