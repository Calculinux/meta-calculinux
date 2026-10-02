# Calculinux in QEMU

`calculinux-qemuarm` runs Calculinux on QEMU's Arm `virt` board. It is not a
PicoCalc simulator (there is no LCD, keyboard MCU, PWM audio or Wi-Fi), but it
boots the same way the device does, so distro, packaging, update and boot-flow
work can be developed and tested without hardware:

```
QEMU pflash: U-Boot (qemu_arm_defconfig + calculinux.cfg)
  -> /boot/boot.scr from the virtio disk   (calculinux-bootscript, RAUC A/B)
  -> /data/fit/zboot_merged_<slot>.img     (merge-dt-overlays-boot)
     or /boot/zboot_merged.img             (default-merged-fit)
  -> Linux (linux-yocto) with init=/sbin/preinit (overlayfs over /data)
```

| | Luckfox Lyra | calculinux-qemuarm |
|---|---|---|
| CPU / RAM | RK3506, 3x Cortex-A7, 128 MiB | `virt`, 3x Cortex-A7, 128 MiB |
| Package arch | `cortexa7t2hf-neon-vfpv4` | same (packages and opkg feed are shared) |
| Kernel | linux-rockchip 6.1 | linux-yocto |
| Base DTB | Lyra DTS | dumped from QEMU at build time |
| Disk | SD card, GPT `ROOT_A/ROOT_B/SWAP/OVERLAY_DATA` | virtio disk, same labels |
| U-Boot env | GPT `ubootenv` partition | second pflash bank (`/dev/mtd0` in Linux) |
| Display | 320x320 SPI LCD | 320x320 virtio-gpu (`video=Virtual-1:320x320`; resizing the window scales it) |
| RAUC compatible | `calculinux-luckfox-lyra` | `calculinux-qemuarm` |

## Build and run

```bash
make qemu-image   # kas-container build meta-calculinux/kas-calculinux-qemuarm.yaml
make qemu         # runqemu ... nographic slirp; log in as root/root, Ctrl-a x quits
```

Or from a kas shell (`./kas-container shell kas-calculinux-qemuarm.yaml`):

```bash
runqemu calculinux-qemuarm calculinux-image wic nographic slirp          # serial only
runqemu calculinux-qemuarm calculinux-image wic slirp                    # with 320x320 display
runqemu calculinux-qemuarm calculinux-image wic nographic slirp snapshot # discard disk writes
```

The U-Boot environment lives in QEMU's second flash bank, which is not backed
by a file: it survives reboots inside one QEMU run and starts fresh (slot A)
on the next run.

## Emulator AppImage

`calculinux-emulator` is one AppImage per host architecture containing QEMU
(SDL window), U-Boot and an image launcher, published next to the SDKs
(`sdk/<feed>/<subfolder>/<arch>/calculinux-emulator-<arch>.AppImage`) and
attached to tagged releases. No QEMU install is needed on the host.

Started without options it opens the launcher: a list of the published system
images (every tagged release, and the latest build of `main` and `develop`).
Pick one and press Enter to boot it; it is downloaded first if needed, with a
progress bar, and an interrupted download resumes. The image used last time
is preselected, so Enter alone boots it again. The same window deletes
downloaded images and discards the changes made in one.

```bash
chmod +x calculinux-emulator-x86_64.AppImage
./calculinux-emulator-x86_64.AppImage                   # launcher, then the 320x320 display in a 640x640 window + serial on the terminal
./calculinux-emulator-x86_64.AppImage --no-launcher     # boot the image used last time straight away
./calculinux-emulator-x86_64.AppImage --list            # published images and which are downloaded
./calculinux-emulator-x86_64.AppImage --select v1.0.0   # boot that image (downloading it if needed), no launcher
./calculinux-emulator-x86_64.AppImage --download v1.0.0 # download only; --remove ID deletes one
./calculinux-emulator-x86_64.AppImage --update-image    # download the image again if a newer one was published
./calculinux-emulator-x86_64.AppImage --scale 3         # 960x960 window (1 = actual size); resizing scales too
./calculinux-emulator-x86_64.AppImage --nographic       # serial console only, no launcher
ssh -p 2222 root@localhost                              # guest SSH (--ssh-port to change, "off" to disable)
./calculinux-emulator-x86_64.AppImage --image build/tmp/deploy/images/calculinux-qemuarm/calculinux-image-calculinux-qemuarm.rootfs.wic.qcow2c
                                                        # boot your own build (qcow2/qcow2c or raw .wic)
./calculinux-emulator-x86_64.AppImage --reset           # start over from the base image
```

The images are listed in
`https://opkg.calculinux.org/emulator/calculinux-qemuarm/index.json`
(`CALCULINUX_EMULATOR_INDEX_URL` overrides; `.github/scripts/generate-emulator-index.py`
writes it on every emulator publish). An image id is the release tag, or
`continuous-main` / `continuous-develop`. Downloads are compressed qcow2
files checked against their `.sha256`. If the index cannot be fetched, the
downloaded images are still offered. `CALCULINUX_EMULATOR_IMAGE_URL` boots
the image at that URL instead, without the launcher.

State lives in `~/.local/share/calculinux-emulator` (`CALCULINUX_EMULATOR_HOME`
overrides): `images/<id>/` holds each downloaded image with its own disk
changes (a qcow2 overlay on the read-only image) and U-Boot environment (RAUC
slot state), so switching images keeps the changes made in each; `local/`
holds those for `--image`. Updating an image to a newer build resets its
changes. A state directory from an older AppImage is converted on first run.
Without FUSE, run with `APPIMAGE_EXTRACT_AND_RUN=1`.

The launcher is [calculinux-emulator-launcher](https://github.com/Calculinux/calculinux-emulator-launcher)
(Dear ImGui on SDL2's software renderer, and libcurl), built by the
`calculinux-emulator-launcher` recipe.

Build it like an SDK (`SDKMACHINE` picks the host):

```bash
./kas-container shell kas-calculinux-qemuarm.yaml -c "bitbake calculinux-emulator -c populate_sdk"
# -> build/tmp/deploy/sdk/calculinux-emulator-x86_64-<version>.AppImage
```

## End-to-end boot test

`.github/scripts/qemu-boot-test.py` drives the serial console and checks the
whole chain: U-Boot runs the boot script and boots the `/boot` FIT, root logs
in on slot A, `fw_printenv` and `rauc status` work, `/etc` is on overlayfs,
systemd finishes booting, then `merge-dt-overlays-boot` writes the per-slot FIT
to `/data` and U-Boot boots it after a reboot.

```bash
./kas-container shell kas-calculinux-qemuarm.yaml -c \
    "python3 /repo/.github/scripts/qemu-boot-test.py --log /work/qemu-boot-test.log"
```

The same checks run against the AppImage with
`--cmd "./calculinux-emulator-x86_64.AppImage --image <disk> --nographic --ssh-port off"`,
after `.github/scripts/emulator-launcher-test.sh` has listed, downloaded and
removed that disk image through the bundled launcher and opened its window on
SDL's dummy video driver.
CI (`.github/workflows/qemu-boot.yml`) runs both, builds the x86_64 and
aarch64 AppImages, and keeps the serial logs as the `qemu-boot-serial-logs`
artifact.

## overlayfs ioctl test

overlayfs is not built into the kernel on Calculinux machines: it is
`overlay.ko` from [Calculinux/overlayfs](https://github.com/Calculinux/overlayfs)
(recipe `overlayfs-calculinux`, branch set by `OVERLAYFS_CALCULINUX_BRANCH`
in the machine configuration), which adds the upper-layer ioctls
calculinux-update uses. `.github/scripts/qemu-overlay-test.py` boots the
emulator and checks them with `ovl-restore` on a scratch overlay and on the
real `/etc` overlay: upper/whiteout/opaque states, restoring a whiteout
(visible to `stat` and `ls` again), `ENODATA` when nothing is below, xattr
whiteouts, argument checks, and a clean kernel log.

```bash
./kas-container shell kas-calculinux-qemuarm.yaml -c \
    "python3 /repo/.github/scripts/qemu-overlay-test.py --log /work/qemu-overlay-test.log"
```

It takes the same `--cmd` option as the boot test.

## Adding another board

Everything board-specific is set by the machine configuration; see
`meta-picocalc-bsp-rockchip/conf/machine/luckfox-lyra.conf` and
`meta-calculinux-bsp-qemu/conf/machine/calculinux-qemuarm.conf`. A board needs:

- `MACHINE_EXTRA_RDEPENDS` for its own packages (bootloader blobs, overlays, tools)
- `CALCULINUX_DT_OVERLAYS`: recipes that stage its `.dtbo` files (may be empty)
- `CALCULINUX_FIT_KERNEL_LOADADDR` / `CALCULINUX_FIT_FDT_LOADADDR` matching its U-Boot memory layout
- `CALCULINUX_BOOT_CONSOLE`, `CALCULINUX_BOOT_BAUDRATE`, `CALCULINUX_BOOT_EXTRA_ARGS`
  (and optionally `CALCULINUX_BOOT_LAST_RESORT`) for `calculinux-bootscript`
- a kernel that deploys `fit_kernel`, `fit_fdt.dtb` and `fit_compression.txt`
- a `u-boot-fw-config.bbappend` providing its `fw_env.config`
- `RAUC_SLOT_A_DEVICE`, `RAUC_SLOT_B_DEVICE`, `RAUC_COMPATIBLE` and the `OVERLAYFS_ETC_*` settings
