# meta-calculinux

This is a **Yocto Project** meta-layer for building a Linux image for the **ClockworkPi PicoCalc** running on the **Luckfox Lyra** board.
The layer uses **[KAS](https://kas.readthedocs.io/)** for configuration management and reproducible builds, and includes **RAUC** support for over-the-air (OTA) updates using a **dual rootfs** setup.

## Automated Builds

This repository includes **GitHub Actions** workflows that automatically build images using self-hosted runners. Builds are triggered on:

- **Push to main or develop branches**: Builds images and uploads artifacts
- **Pull requests to main**: Validates builds without publishing
- **Tagged releases** (v*): Creates GitHub releases with built images
- **Manual workflow dispatch**: Allows on-demand builds

### Pre-built Images

Pre-built images and update bundles are available as:
- **GitHub Release Assets**: For tagged releases (recommended for production)
- **GitHub Artifacts**: For development builds (available for 30 days)

### Download Latest Build

1. Go to the [Actions tab](../../actions) in this repository
2. Click on the latest successful build
3. Download the `calculinux-luckfox-lyra-*` artifact
4. Extract the ZIP file to find:
   - `*.wic.gz` - Flashable SD card images
   - `*.raucb` - RAUC update bundles
   - `build-info.txt` - Build information

---

## Features
- Pre-configured for the Clockwork PicoCalc hardware. The system runs read-only on the internal MMC with an Overlay-FS on the external SD-Card.
- Luckfox Lyra board support.
- KAS-based build setup for reproducible builds.
- **RAUC** OTA update support with dual root filesystem (A/B).
- Ready-to-use shell environment entry after build.
- Extensible - In the future additional boards can be supported.

---

## Prerequisites

Make sure you have the following installed on your build host:

- Docker

---

## Manual Build Instructions

If you prefer to build locally instead of using the automated builds:

1. **Clone this repository**:
   ```bash
   mkdir calculinux-buildsystem && cd calculinux-buildsystem
   git clone https://github.com/Calculinux/meta-calculinux.git
   ```

2. **Run the build with KAS**:
   ```bash
   ./meta-calculinux/kas-container --ssh-dir ~/.ssh build --update meta-calculinux/kas-luckfox-lyra-bundle.yaml
   ```

   This will:
   - Download the Yocto sources.
   - Apply the configurations for the PicoCalc with the Luckfox Lyra.
   - Build the image.

3. **Find the output image**
   After the build completes, the image (picocalc-image-luckfox-lyra.rootfs.wic) will be located in:
   ```
   build/tmp/deploy/images/luckfox-lyra/
   ```

4. **Install**
   Install the image with dd on a Micro-SD card.
   ```
   dd if=build/tmp/deploy/images/luckfox-lyra/picocalc-image-luckfox-lyra.rootfs.wic of=/dev/mmcblk0 bs=4M
   ```

   Create a ext4 partition on the external Picocalc SD-Card which will be mounted at `/data` on the system.

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

## Setting Up Self-Hosted Runners

To set up a self-hosted GitHub Actions runner for building:

1. **Prepare the runner environment**:
   ```bash
   # Run the setup script (no sudo required)
   ./.github/setup-runner.sh
   ```

2. **Configure the GitHub Actions runner**:
   - Follow [GitHub's documentation](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) to add a self-hosted runner
   - Use the tags: `self-hosted`, `Linux`, `X64`
   - Ensure Docker is installed and the runner user is in the docker group

3. **Runner Requirements**:
   - **Disk Space**: At least 100GB free (Yocto builds are large)
   - **RAM**: 8GB minimum, 16GB recommended
   - **Docker**: Required for containerized builds
   - **Persistent Cache**: `~/yocto-cache` for downloads and sstate-cache (no sudo required)

---

## OTA Updates with RAUC

This meta-layer configures **RAUC** for robust **A/B dual rootfs** OTA updates.
The device has two root partitions (`rootfsA` and `rootfsB`). During an update:
1. RAUC installs the new system image to the inactive rootfs.
2. The bootloader is updated to boot from the new rootfs.
3. If the new system boots successfully, it is marked as “good”; otherwise, the system falls back to the previous version.

The system uses a dual-rootfs for proper rollbacks if a update failed. Updates can be installed with rauc.
Copy the `.raucb` file onto the SD-Card and install it with:
```
rauc install picocalc-bundle-luckfox-lyra.raucb
reboot
```

RAUC will automatically boot into the updated rootfs. If the boot fails, the device will revert to the previous rootfs.

More on RAUC: https://rauc.readthedocs.io/

---

## AARCH64 Host Support

KAS does not natively support aarch64 hosts. To build on an aarch64 system, additional packages are required in the Docker image. The automated builds handle this automatically using the `Dockerfile.aarch64`.

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

## References
- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [KAS Documentation](https://kas.readthedocs.io/)
- [RAUC Documentation](https://rauc.readthedocs.io/)
- [Luckfox Lyra Documentation](https://wiki.luckfox.com/Luckfox-Lyra/)


## Acknowledgements
Special thanks to [hisptoot](https://github.com/hisptoot/picocalc_luckfox_lyra/)
for providing the kernel drivers for keyboard, display, and audio support.
