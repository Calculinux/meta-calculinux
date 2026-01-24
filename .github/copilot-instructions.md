# Copilot Instructions for Calculinux

## Project Overview

**Calculinux** is a Yocto-based Linux distribution for the **ClockworkPi Picocalc** device (currently supporting Luckfox Lyra SBC). Key architectural features:

- **KAS-based Build System**: Uses KAS for reproducible configuration management (`kas-base.yaml` + `kas-luckfox-lyra-bundle.yaml`)
- **Multi-layer Architecture**: 
  - `meta-calculinux-distro`: Core distribution config, system image, RAUC update bundles
  - `meta-picocalc-bsp-rockchip`: Board support (kernel, u-boot, device trees, WIC partitioning)
  - `meta-calculinux-apps`: Application recipes (x48ng, kiwix-tools, SDL test apps)
  - `meta-meshtastic`: Meshtastic connectivity support
- **Read-only Root + OverlayFS**: Root filesystem on MMC is read-only; user data persists via OverlayFS on SD card
- **RAUC A/B Updates**: Dual rootfs partitions (ROOT_A/ROOT_B) with atomic OTA updates using dm-verity
- **Device Tree ConfigFS**: Runtime overlay loading via in-kernel `drivers/of/configfs` (no external module)
- **Custom Hardware Drivers**: Picocalc keyboard, LCD (ILI9488 DRM), PWM audio, MFD (from `Calculinux/picocalc-drivers` repo)

## Build System Workflow

### CRITICAL Build Location Rules
- **NEVER** run build commands from within `meta-calculinux/` directory - creates unwanted build artifacts
- **ALWAYS** run from parent `calculinux-build/` directory (typically `/home/<username>/repos/calculinux/calculinux-build/`)
- The `./build` symlink in `meta-calculinux/` points to parent directory but prefer explicit paths

### KAS Container Commands (from calculinux-build/)
```bash
# Full image build
./meta-calculinux/kas-container build ./meta-calculinux/kas-luckfox-lyra-bundle.yaml

# Interactive shell for bitbake commands
./meta-calculinux/kas-container shell ./meta-calculinux/kas-luckfox-lyra-bundle.yaml

# Build specific recipe in shell
./meta-calculinux/kas-container shell ./meta-calculinux/kas-luckfox-lyra-bundle.yaml -c "bitbake <recipe-name>"
```

### Build Artifacts Locations
**IMPORTANT**: Build directory is `../build/` relative to `meta-calculinux/` (i.e., `/home/<username>/repos/calculinux/calculinux-build/build/`), NOT `/build/`

- **Images**: `../build/tmp/deploy/images/luckfox-lyra/calculinux-image-luckfox-lyra.rootfs.wic`
- **RAUC bundles**: `../build/tmp/deploy/images/luckfox-lyra/calculinux-bundle-luckfox-lyra.raucb`
- **IPK packages**: `../build/tmp/deploy/ipk/` (organized by architecture: armv7ahf-neon-vfpv4, all, luckfox_lyra)
- **Build work directory**: `../build/tmp/work/<arch>/<recipe>/<version>/` (contains source, build logs, staging)
- **Compile logs**: `../build/tmp/work/<arch>/<recipe>/<version>/temp/log.do_compile.*`

### Build Targets
- `calculinux-image`: Main system image (defined in `meta-calculinux-distro/recipes-core/image/calculinux-image.bb`)
- `calculinux-bundle`: RAUC update bundle (defined in `meta-calculinux-distro/recipes-core/bundles/calculinux-bundle.bb`)
- `packagegroup-meta-calculinux-apps`: Application bundle (apps layer)

**Always wait for builds to complete before declaring success/failure.**

## Patch Creation Guidelines - READ CAREFULLY

### ABSOLUTELY CRITICAL
**DO NOT** attempt to create or edit patches by hand - spacing/whitespace errors make patches invalid.

### Required Process for ALL Patches
1. Fetch or checkout the actual source code to be patched
2. Make a working copy of the original file
3. Apply your changes to the copy
4. Generate patch using `diff -Naur` or `git diff` against actual modified code
5. **NEVER** fabricate patch content synthetically

### When Modifying Existing Patches
- Retrieve sources, apply patch, modify sources, regenerate full patch from modified sources
- You MAY edit: file paths, patch header comments, remove unwanted hunks
- You MAY NOT: hand-edit patch hunks, "fix" whitespace in patches, adjust line numbers manually

### Patch Application in Recipes
- Patches referenced via `SRC_URI` in KAS files: Use `patches:` section (see `kas-luckfox-lyra-bundle.yaml` for examples)
- Patches in `.bbappend` files: Add to `SRC_URI:append` 
- Store patches in `patches/` directory or recipe-local `files/` subdirectory

## Recipe Development

### Yocto Version and Modern Syntax

**Yocto Version**: Calculinux is based on **Yocto Scarthgap (2024.x)** via Poky

**Important Syntax Changes** - Avoid deprecated patterns:

| ❌ AVOID | ✅ USE INSTEAD | REASON |
|---------|----------------|--------|
| `S = "${WORKDIR}"` | Don't set S for file-only recipes | No longer supported in modern Yocto |
| `${WORKDIR}` in do_install | `${UNPACKDIR}` | Explicit, modern way to reference unpacked source files |
| `file://` with implicit workdir | `${UNPACKDIR}/filename` | Clearer variable usage |
| `FILESEXTRAPATHS` only | `FILESEXTRAPATHS` + explicit paths | Combine with proper file location setup |

**Example - Modern File Recipe** (like usb-gadget-network):
```bitbake
# ✅ CORRECT - Modern approach
SUMMARY = "My Package"
LICENSE = "MIT"

SRC_URI = " \
    file://myfile.sh \
    file://myconfig.conf \
"

# DO NOT set S = "${WORKDIR}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/myfile.sh ${D}${bindir}/
    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/myconfig.conf ${D}${sysconfdir}/
}
```

**Why these changes**:
- `${UNPACKDIR}` is explicitly the location of unpacked files from `SRC_URI`
- Yocto automatically manages build directories
- Setting `S` is only needed for recipes that have actual source to build from

### Finding Existing Recipes
**Always** search https://layers.openembedded.org/layerindex/branch/master/recipes/?q=<package-name> before creating new recipes. Check for both the package and its dependencies.

### Recipe Naming Conventions
- Format: `<package-name>_<version>.bb` (e.g., `x48ng_git.bb`, `circumflex_3.8.bb`)
- Use `_git.bb` for git-sourced recipes with `SRCREV`
- Version in filename must match `PV` variable

### Common Recipe Patterns in This Codebase

**Shared source includes**: For drivers sharing a git repo (see `picocalc-drivers-source.inc`):
```bitbake
PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;branch=main"
SRCREV = "<commit-hash>"
S = "${WORKDIR}/git"
```

**Device-specific recipes**: Set `COMPATIBLE_MACHINE = "luckfox-lyra"` for hardware-specific packages

**Kernel modules**: Inherit `module` class, depend on `virtual/kernel`, use `KERNEL_MODULE_AUTOLOAD` for auto-loading

### Layer Dependencies
Check `conf/layer.conf` in each layer for `LAYERDEPENDS`. Example dependency chain:
- `meta-calculinux-apps` → depends on → `meta-calculinux-distro` + `meta-meshtastic`
- All layers depend on `core` (from poky)

## Distro Configuration

### Version Management (`meta-calculinux-distro/conf/distro/calculinux-distro.conf`)
- Local builds: `DISTRO_VERSION = "1.0.0-dev+<git-short-hash>"`
- CI overrides via `kas-ci-override.yaml` using `local_conf_header`
- Release tags: `v1.0.0-alpha4`
- Continuous: `1.0.0-continuous+<hash>`
- Develop: `1.0.0-develop+<hash>`

### Package Feeds
- Base URL: `https://opkg.calculinux.org/`
- Structure: `ipk/${DISTRO_CODENAME}/${CALCULINUX_FEED_SUBFOLDER}/<arch>/`
- `DISTRO_CODENAME` defaults to machine name (`luckfox-lyra` → codename "walnascar")
- `CALCULINUX_FEED_SUBFOLDER`: `continuous`, `release`, or branch name

### Key Distro Features
```bitbake
DISTRO_FEATURES += "ipv4 usbhost usbgadget wifi overlayfs rauc read-only-rootfs systemd"
TCLIBC = "musl"  # Uses musl libc, not glibc
```

## Machine Configuration

### Luckfox Lyra Machine (`meta-picocalc-bsp-rockchip/conf/machine/luckfox-lyra.conf`)
- SOC: Rockchip RK3506 (Cortex-A7)
- Bootloader: U-Boot with `rk3506_luckfox_defconfig`
- Kernel: Device tree `rk3506g-luckfox-lyra.dtb`
- Partitioning: Custom WIC file `luckfox-lyra.wks.in` defines boot/rootfs A/B/overlay layout
- RAUC slots: `/dev/disk/by-partlabel/ROOT_A` and `ROOT_B`

### Device Tree Workflow
1. Picocalc-specific device tree data in `picocalc-devicetree` recipe (`.dtsi` files)
2. Kernel recipe copies these into kernel source tree before compilation (`do_prepare_kernel_picocalc`)
3. Runtime overlays via ConfigFS (no dtbocfg module needed):
   ```bash
   mkdir /sys/kernel/config/device-tree/overlays/<name>
   cat overlay.dtbo > /sys/kernel/config/device-tree/overlays/<name>/dtbo
   echo 1 > /sys/kernel/config/device-tree/overlays/<name>/status
   ```

## Image and Update System

### Image Types
- `calculinux-image.bb`: Root filesystem with SystemD, package management, overlayfs-etc
- Uses `rockchip-image.bbclass` for RK-specific filesystem options
- Inherits `core-image extrausers` for user setup

### OverlayFS Configuration
- Mounts: `/etc`, `/root`, `/home`, `/var`, `/usr`, `/opt` overlaid on SD card partition
- Partition label: `OVERLAY_DATA`
- Custom init: `overlayfs-etc-preinit.sh.in` handles partition growth and overlay mounting
- Original read-only content accessible in `/data/overlay/<path>/lower/` 

### RAUC Updates
- Bundle format: `verity` (dm-verity for integrity)
- Compatible string: `calculinux-luckfox-lyra` (must match device)
- Bundle signing: Development keys in `meta-calculinux-distro/recipes-core/bundles/files/`
- CLI tool: `calculinux-update` (Python/Typer) lists/downloads/installs bundles from mirror

## Development Patterns

### Temporary Files
Always create in `/tmp` or `./tmp/` within the repository

### External Source Development
For iterative driver development, use `EXTERNALSRC`:
```bitbake
# In recipe or local.conf
EXTERNALSRC:pn-<recipe> = "/path/to/local/source"
EXTERNALSRC_BUILD:pn-<recipe> = "/path/to/local/source"
```

### Kernel Configuration Fragments
Located in `meta-picocalc-bsp-rockchip/recipes-kernel/linux/linux-rockchip-6.1/`: `base-configs.cfg`, `display.cfg`, `wifi.cfg`, `rauc.cfg`, etc. Applied via `KERNEL_CONFIG_FRAGMENTS` variable.

### Testing Recipe Changes
```bash
# From kas shell
bitbake -c cleanall <recipe-name>  # Clear all recipe state
bitbake <recipe-name>              # Rebuild from scratch
```

## GitHub CI Workflows

Main workflow: `.github/workflows/build.yml`
- Triggers: Push to main/develop, tags (`v*`), PRs to main
- Builds images, SDKs (x86_64 + aarch64), packages
- Syncs packages to opkg repository
- Creates GitHub releases for tags
- Discord notifications for releases

Custom actions in `.github/actions/`:
- `setup-build-env`: Cache setup (DL_DIR, SSTATE_DIR)
- `sync-packages`: Rsync packages to repo, generate indexes
- `discord-notify`: Release announcements

## Key Files Reference

- **Build entry point**: `kas-luckfox-lyra-bundle.yaml` (includes `kas-base.yaml`)
- **Main image recipe**: `meta-calculinux-distro/recipes-core/image/calculinux-image.bb`
- **Distro config**: `meta-calculinux-distro/conf/distro/calculinux-distro.conf`
- **Machine config**: `meta-picocalc-bsp-rockchip/conf/machine/luckfox-lyra.conf`
- **Kernel config**: `meta-picocalc-bsp-rockchip/recipes-kernel/linux/linux-rockchip_6.1.bbappend`
- **WIC partitioning**: `meta-picocalc-bsp-rockchip/wic/luckfox-lyra.wks.in`
- **RAUC bundle**: `meta-calculinux-distro/recipes-core/bundles/calculinux-bundle.bb`
- **Driver sources**: External repo referenced in `picocalc-drivers-source.inc`
