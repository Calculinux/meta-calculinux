# meta-calculinux

This is a **Yocto Project** meta-layer for building **Calculinux**, a custom Linux distribution for the **ClockworkPi Picocalc** device. It currently supports the **Luckfox Lyra** single-board computer (SBC), with plans to support additional SBCs in the future.

The layer uses **[KAS](https://kas.readthedocs.io/)** for configuration management and reproducible builds, and includes **RAUC** support for over-the-air (OTA) updates using a **dual rootfs** setup.

## About Calculinux

**Calculinux** is a specialized Linux distribution designed specifically for the Picocalc calculator device. It provides:
- Optimized performance for calculator hardware and user interface
- Hardware-specific drivers for keyboard, display, and audio components
- A secure, updatable system with read-only root filesystem
- Integration with Picocalc's unique form factor and use cases

The distribution is built using the Yocto Project, ensuring a minimal, efficient, and customizable embedded Linux system tailored for the Picocalc's requirements.

---

## Features
- **Calculinux Distribution**: A custom Linux distribution designed specifically for the Clockwork Picocalc hardware
- **Read-only Root Filesystem**: The system runs read-only on the internal MMC with an Overlay-FS on the external SD-Card for data persistence
- **Luckfox Lyra Support**: Full board support for the Luckfox Lyra SBC
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

1. **Clone this repository**:
   ```bash
   mkdir calculinux-build && cd calculinux-build
   git clone https://github.com/calculinux/meta-calculinux.git meta-calculinux
   ```

2. **Build Calculinux for Luckfox Lyra with KAS**:
   ```bash
   ./meta-calculinux/kas-container --ssh-dir ~/.ssh build --update meta-calculinux/kas-luckfox-lyra-bundle.yaml
   ```

   This will:
   - Download the Yocto sources
   - Apply the configurations for Calculinux on the Picocalc with Luckfox Lyra
   - Build the complete Calculinux distribution image

3. **Find the Calculinux image**
   After the build completes, the Calculinux distribution image (picocalc-image-luckfox-lyra.rootfs.wic) will be located in:
   ```
   build/tmp/deploy/images/luckfox-lyra/
   ```

4. **Install Calculinux**
   Install the Calculinux image with dd on a Micro-SD card:
   ```
   dd if=build/tmp/deploy/images/luckfox-lyra/picocalc-image-luckfox-lyra.rootfs.wic of=/dev/mmcblk0 bs=4M
   ```

   Create an ext4 partition on the external Picocalc SD-Card which will be mounted at `/data` on the Calculinux system.

---

## Getting a Shell Environment

To drop into the Yocto build shell environment (for custom builds, debugging, or running `bitbake` commands manually):

```bash
./meta-calculinux/kas-container --ssh-dir ~/.ssh shell meta-calculinux/kas-luckfox-lyra-bundle.yaml
```

Inside this shell, you can run commands like:
```bash
bitbake virtual/kernel
```

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
rauc install picocalc-bundle-luckfox-lyra.raucb
reboot
```

RAUC will automatically boot into the updated rootfs. If the boot fails, the device will revert to the previous rootfs.

More on RAUC: https://rauc.readthedocs.io/

---

## AARCH64 Host

KAS does not natively support aarch64 hosts. To build on an aarch64 system, additional packages are required in the Docker image. These can be included by manually rebuilding the image.

Use the following command to build the image:

```
docker build -t ghcr.io/siemens/kas/kas:4.7 -f meta-calculinux/Dockerfile.aarch64 meta-calculinux
```

This command must be **run before starting** the build.
Note: It will overwrite the local KAS container. If you need to rebuild the image, you must first remove the existing one:

```
docker rmi ghcr.io/siemens/kas/kas:4.7
```

---

## References
- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [KAS Documentation](https://kas.readthedocs.io/)
- [RAUC Documentation](https://rauc.readthedocs.io/)
- [Luckfox Lyra Documentation](https://wiki.luckfox.com/Luckfox-Lyra/)


## Acknowledgements
Special thanks to [hisptoot](https://github.com/hisptoot/picocalc_luckfox_lyra/)
for providing the kernel drivers for keyboard, display, and audio support.