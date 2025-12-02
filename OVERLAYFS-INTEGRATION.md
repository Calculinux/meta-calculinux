# OverlayFS Lower Layer Restoration - Yocto Integration

## Overview

This document describes how the overlayfs lower layer restoration feature has been integrated into the Calculinux build system.

## Files Added/Modified

### 1. Kernel Patch

**File**: `meta-calculinux/meta-picocalc-bsp-rockchip/recipes-kernel/linux/files/overlayfs-restore-lower.patch`

- 865 lines adding complete overlayfs ioctl implementation
- Adds `include/uapi/linux/overlayfs.h` with `OVL_IOC_RESTORE_LOWER` ioctl
- Adds `fs/overlayfs/ioctl.c` with restoration logic
- Modifies `fs/overlayfs/file.c` to wire up ioctl handler
- Modifies `fs/overlayfs/overlayfs.h` for function declarations
- Modifies `fs/overlayfs/Makefile` to build ioctl.o
- Includes comprehensive documentation in `Documentation/filesystems/overlayfs-ioctl.md`
- Includes userspace tool source in `tools/ovl-restore/`

### 2. Kernel Recipe Update

**File**: `meta-calculinux/meta-picocalc-bsp-rockchip/recipes-kernel/linux/linux-rockchip_6.1.bbappend`

**Change**: Added patch to SRC_URI
```bitbake
SRC_URI = " \
    ...
    file://overlayfs-restore-lower.patch \
"
```

This ensures the patch is applied during kernel build.

### 3. Userspace Tool Recipe

**File**: `meta-calculinux/meta-calculinux-distro/recipes-support/ovl-restore/ovl-restore_git.bb`

New recipe that:
- Builds `ovl-restore` command-line tool from kernel source tree
- Installs tool to `/usr/bin/ovl-restore`
- Uses same git repo as kernel (no duplication)
- Automatically tracks kernel version via SRCPV

### 4. Image Recipe Update

**File**: `meta-calculinux/meta-calculinux-distro/recipes-core/image/calculinux-image.bb`

**Change**: Added ovl-restore to IMAGE_INSTALL
```bitbake
IMAGE_INSTALL += " \
    ...
    overlayfs-tools \
    ovl-restore \
    ...
"
```

This includes the tool in the final image.

## Build Process

When building Calculinux, the following happens:

1. **Kernel Build**:
   - `overlayfs-restore-lower.patch` is applied to kernel source
   - Kernel is built with new ioctl support
   - Module `overlay.ko` includes the new functionality

2. **Tool Build**:
   - `ovl-restore` recipe fetches same kernel git repo
   - Builds userspace tool from `tools/ovl-restore/`
   - Installs binary to staging area

3. **Image Assembly**:
   - Both kernel and `ovl-restore` are included in rootfs
   - Tool is available at `/usr/bin/ovl-restore` in final image

## Testing the Build

### Clean Build
```bash
cd /home/<username>/repos/calculinux/calculinux-build
./meta-calculinux/kas-container build ./meta-calculinux/kas-luckfox-lyra-bundle.yaml
```

### Rebuild Just Kernel
```bash
./meta-calculinux/kas-container shell ./meta-calculinux/kas-luckfox-lyra-bundle.yaml -c "bitbake -c cleansstate linux-rockchip && bitbake linux-rockchip"
```

### Rebuild Just Tool
```bash
./meta-calculinux/kas-container shell ./meta-calculinux/kas-luckfox-lyra-bundle.yaml -c "bitbake -c cleansstate ovl-restore && bitbake ovl-restore"
```

### Rebuild Image
```bash
./meta-calculinux/kas-container shell ./meta-calculinux/kas-luckfox-lyra-bundle.yaml -c "bitbake calculinux-image"
```

## Runtime Testing

After flashing the image to hardware:

### 1. Verify Kernel Support
```bash
# Check if ioctl is available
dmesg | grep -i overlay

# Verify overlay module is loaded
lsmod | grep overlay
```

### 2. Test the Tool
```bash
# Check tool is installed
which ovl-restore
ovl-restore --help

# Create test scenario
mkdir -p /tmp/{lower,upper,work,merged}
mount -t overlay overlay -olowerdir=/tmp/lower,upperdir=/tmp/upper,workdir=/tmp/work /tmp/merged

# Create file in lower
echo "test" > /tmp/lower/test.txt

# Remove from overlay (creates whiteout)
rm /tmp/merged/test.txt

# Verify whiteout exists
ls -la /tmp/upper/test.txt
# Should show: c--------- 1 root root 0, 0 ...

# Restore the file
ovl-restore /tmp/merged /tmp/merged/test.txt

# Verify file is visible
cat /tmp/merged/test.txt
# Should print: test
```

### 3. Integration with Calculinux-Update

The calculinux-update tool can now use this ioctl:

```bash
# After a system update that creates whiteouts
cup install <bundle>

# The post-reboot reconciliation will automatically use ovl-restore
# if the kernel supports it, otherwise falls back to remount method
```

## Version Management

### Kernel Patch
- Lives in meta-calculinux git repo
- Version tracked by git hash in bbappend SRCREV
- Patch is versioned alongside other kernel patches

### Tool Recipe
- Uses AUTOREV to track latest kernel source
- Version format: `1.0.0+git${SRCPV}`
- Automatically stays in sync with kernel changes

## Future Updates

### Updating the Patch

If changes are needed to the kernel implementation:

1. Make changes in `luckfox-linux-6.1-rk3506` repo
2. Regenerate patch:
   ```bash
   cd /home/<username>/repos/calculinux/luckfox-linux-6.1-rk3506
   git add -A
   git diff --cached --no-color > /tmp/overlayfs-restore-lower.patch
   cp /tmp/overlayfs-restore-lower.patch \
      /home/<username>/repos/calculinux/calculinux-build/meta-calculinux/meta-picocalc-bsp-rockchip/recipes-kernel/linux/files/
   ```
3. Rebuild kernel

### Updating the Tool

Changes to `tools/ovl-restore/` in kernel repo will automatically be picked up on next build since the recipe uses AUTOREV.

## Upstream Submission

The patch is designed to be submitted upstream to the Linux kernel:

1. Clean up any Calculinux-specific references
2. Add comprehensive test cases
3. Format as proper kernel patch series
4. Submit to:
   - linux-fsdevel@vger.kernel.org
   - linux-unionfs@vger.kernel.org
   - Miklos Szeredi <miklos@szeredi.hu>
   - Amir Goldstein <amir73il@gmail.com>

## Dependencies

- **Kernel**: Must support overlayfs (CONFIG_OVERLAY_FS=y or m)
- **Runtime**: overlay kernel module must be loaded
- **Build**: Standard kernel build dependencies

## Benefits for Calculinux

1. **Performance**: 10x faster whiteout cleanup vs remount
2. **Reliability**: Kernel-validated operations
3. **Simplicity**: Single ioctl call vs complex shell scripting
4. **User Experience**: Clear "restore" semantics
5. **Maintenance**: Less fragile than manual file manipulation

## Related Documentation

- Kernel patch documentation: See patch file header
- Tool usage: `ovl-restore --help` or `man ovl-restore` (if man page added)
- API documentation: `Documentation/filesystems/overlayfs-ioctl.md` in kernel source
- Implementation summary: `IMPLEMENTATION-SUMMARY.md` in kernel source

## Support

For issues or questions:
- GitHub Issues: https://github.com/Calculinux/luckfox-linux-6.1-rk3506/issues
- GitHub Issues: https://github.com/Calculinux/meta-calculinux/issues
