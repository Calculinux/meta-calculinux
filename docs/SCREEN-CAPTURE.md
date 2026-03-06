# Screen Capture with FFmpeg on PicoCalc

## Overview

Calculinux includes FFmpeg with DRM/KMS framebuffer capture support, enabling direct screen capture from the PicoCalc's ILI9488 DRM display without needing X11 or Wayland.

## How It Works

FFmpeg's `kmsgrab` input device captures directly from the DRM/KMS framebuffer using the Linux Direct Rendering Manager (DRM) API. This provides efficient, low-overhead screen capture.

## Basic Usage

### Capture a single frame (screenshot)

```bash
ffmpeg -device /dev/dri/card0 -f kmsgrab -i - -vframes 1 screenshot.png
```

### Record video from the screen

```bash
ffmpeg -device /dev/dri/card0 -f kmsgrab -i - \
    -vf 'hwdownload,format=bgr0' \
    -c:v libx264 -preset ultrafast \
    output.mp4
```

### Stream to a file with specific framerate

```bash
ffmpeg -framerate 30 -device /dev/dri/card0 -f kmsgrab -i - \
    -vf 'hwdownload,format=bgr0' \
    -c:v libx264 -preset veryfast -crf 23 \
    screencast.mp4
```

### Capture and encode with h264_v4l2m2m (hardware encoder)

If hardware encoding is available:

```bash
ffmpeg -framerate 15 -device /dev/dri/card0 -f kmsgrab -i - \
    -vf 'hwdownload,format=nv12' \
    -c:v h264_v4l2m2m -b:v 2M \
    screencast.mp4
```

## Important Notes

### Permissions

You need access to `/dev/dri/card0`. The default `pico` user is in the `video` and `render` groups, which should provide the necessary permissions.

If you encounter permission errors:

```bash
# Check your groups
groups

# Add user to video group (if not already)
sudo usermod -a -G video,render $USER

# Re-login or use newgrp
newgrp video
```

### Performance Considerations

- Screen capture can be CPU-intensive, especially on the RK3506's Cortex-A7
- Use lower framerates (10-15 fps) for better performance
- Consider using hardware encoding if available
- The `ultrafast` or `veryfast` presets are recommended for real-time capture

### Display Resolution

The PicoCalc's LCD is 320x480. FFmpeg will automatically detect and use this resolution.

## Advanced Examples

### Capture with timestamp overlay

```bash
ffmpeg -framerate 10 -device /dev/dri/card0 -f kmsgrab -i - \
    -vf "hwdownload,format=bgr0,drawtext=fontfile=/usr/share/fonts/terminus/ter-u32n.otb:text='%{localtime\:%X}':fontcolor=white:x=10:y=10" \
    -c:v libx264 -preset ultrafast \
    timestamped.mp4
```

### Capture for a specific duration

```bash
ffmpeg -t 10 -framerate 15 -device /dev/dri/card0 -f kmsgrab -i - \
    -vf 'hwdownload,format=bgr0' \
    -c:v libx264 -preset veryfast \
    10sec.mp4
```

### Create an animated GIF

```bash
ffmpeg -t 5 -framerate 10 -device /dev/dri/card0 -f kmsgrab -i - \
    -vf 'hwdownload,format=bgr0,fps=10,scale=320:-1:flags=lanczos' \
    -c:v gif \
    animation.gif
```

## Troubleshooting

### "Cannot open device /dev/dri/card0"

Check that the DRM device exists:

```bash
ls -l /dev/dri/
```

Verify the ILI9488 DRM driver is loaded:

```bash
dmesg | grep -i ili9488
lsmod | grep ili9488
```

### "Permission denied" errors

Ensure you're in the correct groups:

```bash
groups
# Should include: video render
```

### Low framerate or dropped frames

- Reduce the target framerate: `-framerate 10` or even `-framerate 5`
- Use a faster preset: `-preset ultrafast`
- Lower the video quality: `-crf 28` (higher = lower quality)
- Reduce resolution if needed: `-vf 'hwdownload,format=bgr0,scale=160:240'`

### Black screen or corrupt output

The DRM plane might need to be active. Try running a test application first:

```bash
# Run SDL test to ensure display is active
sdl2-test

# Then capture in another terminal
```

## Implementation Details

### Recipe Configuration

FFmpeg support is enabled via a bbappend in `meta-calculinux-distro`:

```bitbake
# meta-calculinux-distro/recipes-multimedia/ffmpeg/ffmpeg_%.bbappend
PACKAGECONFIG:append = " drm"
PACKAGECONFIG[drm] = "--enable-libdrm,--disable-libdrm,libdrm"
```

This enables:
- The `--enable-libdrm` configure flag
- Dependency on `libdrm` library
- Support for `kmsgrab` input device

### Dependencies

- `libdrm` - DRM/KMS library
- Kernel DRM subsystem with the ILI9488 DRM driver
- `/dev/dri/card0` device node

## References

- [FFmpeg kmsgrab documentation](https://trac.ffmpeg.org/wiki/Capture/Desktop)
- [Linux DRM documentation](https://www.kernel.org/doc/html/latest/gpu/drm-kms.html)
- PicoCalc LCD driver: `picocalc-drivers/picocalc_lcd_drm/`
