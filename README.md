# meta-calculinux

This is a **Yocto Project** meta-layer for building **Calculinux**, a custom Linux distribution for the **ClockworkPi Picocalc** device. It currently supports the **Luckfox Lyra** single-board computer (SBC), with plans to support additional SBCs in the future.

The layer uses **[KAS](https://kas.readthedocs.io/)** for configuration management and reproducible builds, and includes **RAUC** support for over-the-air (OTA) updates using a **dual rootfs** setup.

## About Calculinux

**Calculinux** is a specialized Linux distribution designed specifically for the Picocalc by ClockworkPi with a Luckfox Lyra installed instead of the typical Raspberry Pi Pico. It provides:
- Optimized performance for low memory and low power hardware
- Hardware-specific drivers for keyboard, display, and audio components
- A secure, updatable system with read-only root filesystem
- Integration with Picocalc's unique form factor and use cases

The distribution is built using the Yocto Project, ensuring a minimal, efficient, and customizable embedded Linux system tailored for the Picocalc's requirements.

### Pre-built Images

Pre-built images and update bundles are available for download from the [latest release](../../releases/latest). Each release includes:
- `*.wic.gz` - Flashable SD card images
- `*.raucb` - RAUC update bundles for OTA updates
- Build information and checksums

Other CI builds are available from the [packages server](https://opkg.calculinux.org/) in the update or image folders.

---

## Features
- **Calculinux Distribution**: A custom Linux distribution designed specifically for the Clockwork Picocalc hardware
- **Read-only Root Filesystem**: The system runs read-only on the internal MMC with an Overlay-FS on the external SD-Card for data persistence
- **Luckfox Lyra Support**: Full board support for the Luckfox Lyra SBC
- **Device Tree Overlays**: Runtime overlay loading via the in-kernel ConfigFS interface (drivers/of/configfs)
- **KAS-based Build System**: Reproducible builds using KAS configuration management
- **RAUC OTA Updates**: Over-the-air update support with dual root filesystem (A/B) for safe updates and rollbacks
- **Development-ready**: Ready-to-use shell environment entry after build for development and debugging
- **Extensible Architecture**: Designed to support additional SBCs in the future beyond Luckfox Lyra

---

## Prerequisites

Make sure you have the following installed on your build host:

- Docker

---

## Build Instructions

### Quick Start with Makefile

The easiest way to build Calculinux is using the provided Makefile:

1. **Clone this repository**:
   ```bash
   mkdir calculinux-build && cd calculinux-build
   git clone <repository-url> meta-calculinux
   cd meta-calculinux
   ```

2. **Build the system image**:
   ```bash
   make image
   ```

3. **View all available targets**:
   ```bash
   make help
   ```

Common Makefile targets:
- `make image` - Build the complete Calculinux system image
- `make bundle` - Build a RAUC update bundle
- `make shell` - Open an interactive bitbake shell
- `make recipe RECIPE=<name>` - Build a specific recipe
- `make clean-recipe RECIPE=<name>` - Clean a specific recipe
- `make status` - Show build status and artifacts

**Custom build directories**: By default, builds run in the parent directory. To use a different location:
```bash
make BUILD_ROOT=/path/to/build/dir image
```

### Manual Build with KAS

If you prefer to use KAS directly without the Makefile:

1. **Clone this repository**:
   ```bash
   mkdir calculinux-build && cd calculinux-build
   git clone <repository-url> meta-calculinux
   ```

2. **Build Calculinux for Luckfox Lyra with KAS**:
   ```bash
   ./meta-calculinux/kas-container --ssh-dir ~/.ssh build --update meta-calculinux/kas-luckfox-lyra-bundle.yaml
   ```

   This will:
   - Download the Yocto sources
   - Apply the configurations for Calculinux on the Picocalc with Luckfox Lyra
   - Build the complete Calculinux distribution image

### Finding Build Artifacts

After the build completes, the Calculinux distribution image will be located in:
```
build/tmp/deploy/images/luckfox-lyra/calculinux-image-luckfox-lyra.rootfs.wic
```

RAUC update bundles are in the same directory:
```
build/tmp/deploy/images/luckfox-lyra/calculinux-bundle-luckfox-lyra.raucb
```

### Installing Calculinux

Install the Calculinux image with dd on a Micro-SD card:
```bash
dd if=build/tmp/deploy/images/luckfox-lyra/calculinux-image-luckfox-lyra.rootfs.wic of=/dev/mmcblk0 bs=4M status=progress
```

On first boot, the user partition will be configured to fill the rest of the SD card.

---

## Development Workflow

### Interactive Shell Environment

To drop into the Yocto build shell environment for custom builds, debugging, or running `bitbake` commands manually:

**Using Makefile**:
```bash
make shell
```

**Using KAS directly**:
```bash
./meta-calculinux/kas-container --ssh-dir ~/.ssh shell meta-calculinux/kas-luckfox-lyra-bundle.yaml
```

Inside this shell, you can run commands like:
```bash
bitbake virtual/kernel
bitbake -c menuconfig linux-rockchip
bitbake-layers show-recipes
```

### Building Specific Recipes

**Using Makefile**:
```bash
# Build a specific recipe
make recipe RECIPE=x48ng

# Clean and rebuild a recipe
make clean-recipe RECIPE=x48ng
make recipe RECIPE=x48ng

# Open development shell for a recipe
make devshell RECIPE=linux-rockchip
```

**Using KAS directly**:
```bash
./meta-calculinux/kas-container shell meta-calculinux/kas-luckfox-lyra-bundle.yaml -c "bitbake x48ng"
```

### Searching for Recipes

```bash
# Find recipes by name
make list-recipes SEARCH=sdl

# List all Calculinux images
make list-images
```

## Device Tree Overlays

The kernel is now patched with the upstream `drivers/of/configfs` implementation, so overlays can be
managed directly through ConfigFS at runtime without building an external module:

1. Make sure ConfigFS is mounted (systemd will normally handle this via `sys-kernel-config.mount`, but you
   can do it manually with `mount -t configfs none /sys/kernel/config`).
2. Create a directory under `/sys/kernel/config/device-tree/overlays/<name>` for each overlay you want to
   stage.
3. Copy the compiled overlay blob (`*.dtbo`) into the `dtbo` attribute inside that directory.
4. Echo `1` into the matching `status` attribute to apply the overlay, or `0` to remove it again.

This matches the workflow documented upstream in the `dtbocfg`/OpenWrt examples while keeping the code in-tree.
Place reusable overlays in `/lib/firmware/overlays` (or another directory of your choosing) so
they can be easily copied into ConfigFS when needed.

---

## OTA Updates with RAUC

This meta-layer configures **RAUC** for robust **A/B dual rootfs** OTA updates in Calculinux.
The device has two root partitions (`rootfsA` and `rootfsB`). During an update:
1. RAUC installs the new Calculinux system image to the inactive rootfs
2. The bootloader is updated to boot from the new rootfs
3. If the new system boots successfully, it is marked as "good"; otherwise, the system falls back to the previous version

Calculinux uses a dual-rootfs setup for proper rollbacks if an update fails. Updates can be installed with rauc.
Copy the `.raucb` file onto the SD-Card and install it with:
```
rauc install calculinux-bundle-luckfox-lyra.raucb
reboot
```

RAUC will automatically boot into the updated rootfs. If the boot fails, the device will revert to the previous rootfs.

More on RAUC: https://rauc.readthedocs.io/

---

## AARCH64 Host Support

KAS does not natively support aarch64 hosts. To build on an aarch64 system, additional packages are required in the Docker image.

For manual builds on aarch64, use the following command to build the image:

```bash
docker build -t ghcr.io/siemens/kas/kas:4.7 -f meta-calculinux/Dockerfile.aarch64 meta-calculinux
```

This command must be **run before starting** the build.
Note: It will overwrite the local KAS container. If you need to rebuild the image, you must first remove the existing one:

```bash
docker rmi ghcr.io/siemens/kas/kas:4.7
```

---

## Creating Releases

To create an official Calculinux release with builds, see [Release Process](docs/RELEASE-PROCESS.md).

Quick summary:
```bash
# Create and push a git tag
git tag v1.0.0
git push origin v1.0.0

# Create release with automated builds
make release TAG=v1.0.0
```

This creates a GitHub release with images, bundles, and SDKs automatically attached.

## References
- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [KAS Documentation](https://kas.readthedocs.io/)
- [RAUC Documentation](https://rauc.readthedocs.io/)
- [Luckfox Lyra Documentation](https://wiki.luckfox.com/Luckfox-Lyra/)


## Acknowledgements
Special thanks to [hisptoot](https://github.com/hisptoot/picocalc_luckfox_lyra/)
for providing the kernel drivers for keyboard, display, and audio support.
