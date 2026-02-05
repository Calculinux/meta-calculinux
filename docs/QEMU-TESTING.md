# QEMU ARM32 Testing for Calculinux

This document describes how to test calculinux-update and ovl-restore components on ARM32 using QEMU before deploying to physical hardware (e.g. Luckfox Lyra).

## Quick Start

Build and run QEMU (optional run step):

```bash
./scripts/run-qemu-arm32-tests.sh both
```

Or build only:

```bash
./scripts/run-qemu-arm32-tests.sh build
```

Then run tests inside QEMU (see Manual Steps below).

## Manual Steps

### 1. Build Test Image

From the meta-calculinux repository root:

```bash
./kas-container build kas-qemu-arm32-test.yaml
# or: kas build kas-qemu-arm32-test.yaml --build-dir ./build
```

Build output is in `./build` (or `KAS_BUILD_DIR` if set).

### 2. Boot QEMU

```bash
cd build
source ../layers/poky/oe-init-build-env .
runqemu qemu-arm32-test nographic
```

Or use the script:

```bash
KAS_BUILD_DIR=/path/to/build ./scripts/run-qemu-arm32-tests.sh test
```

### 3. Run Tests Inside QEMU

After boot, log in as root (no password) and run:

```bash
/opt/tests/run-ioctl-tests.sh
```

## What Gets Tested

- ARM32 architecture (armv7l)
- OverlayFS mount for /etc, /root, /home, /var, /usr, /opt
- ovl-restore binary and ioctl (when calculinux-update overlayfs module is present)
- Optional: Python ioctl struct size and pointer handling (test_arm32_ioctl.py)

## Debugging

View kernel logs:

```bash
dmesg | grep overlay
```

Test ovl-restore manually:

```bash
ovl-restore --help
ovl-restore --test / /path/to/file
```

Run Python tests (if calculinux_update is installed):

```bash
cd /usr/lib/python3.*/site-packages/calculinux_update
python3 -m pytest tests/ -v
```

## CI Integration

The workflow `.github/workflows/qemu-arm32-tests.yml` runs on pull requests that touch:

- calculinux-update recipe or related
- Kernel (ovl-restore) recipes
- RAUC integration
- opkg modifications
- QEMU machine or test image

It builds the QEMU ARM32 test image; optional QEMU boot runs when the build environment provides `runqemu`.

## Machine and Image

- **Machine:** `qemu-arm32-test` (meta-calculinux-distro/conf/machine/qemu-arm32-test.conf)
- **Kernel:** linux-yocto-custom 6.1 with overlayfs-restore-lower patch
- **Image:** calculinux-qemu-test-image (minimal image with overlayfs-etc, opkg, ovl-restore, calculinux-update)
