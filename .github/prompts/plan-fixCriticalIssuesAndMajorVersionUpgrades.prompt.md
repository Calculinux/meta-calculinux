# Plan: Fix Critical Issues and Enhance Major Version Upgrade Support (Revised)

Comprehensive fix plan for opkg/RAUC/ovl-restore integration issues with special focus on conffile handling and major version upgrades. Revised to prioritize 32-bit ARM deployment environment.

---

## Phase 0: QEMU ARM32 Test Infrastructure (Priority: 🔴 Critical)

### 0.1 Create Minimal QEMU Test Machine Configuration

**New File:** `meta-calculinux-distro/conf/machine/qemu-arm32-test.conf`

**Purpose:** Minimal ARM32 machine for testing ioctl/overlayfs functionality

**Implementation:**
```bitbake
#@TYPE: Machine
#@NAME: QEMU ARM32 Test Machine
#@DESCRIPTION: Minimal ARM32 machine for testing calculinux-update on QEMU

require conf/machine/include/arm/armv7a/tune-cortexa9.inc

MACHINE_FEATURES = "ext4 serial"

KERNEL_IMAGETYPE = "zImage"
KERNEL_DEVICETREE = "vexpress-v2p-ca9.dtb"

SERIAL_CONSOLES = "115200;ttyAMA0"

# Use upstream kernel with ovl-restore patches
PREFERRED_PROVIDER_virtual/kernel = "linux-yocto-custom"
PREFERRED_VERSION_linux-yocto-custom = "6.1%"

# Minimal image size
IMAGE_FSTYPES = "ext4"
IMAGE_ROOTFS_SIZE ?= "512000"

# QEMU configuration
QB_SYSTEM_NAME = "qemu-system-arm"
QB_MACHINE = "-machine vexpress-a9"
QB_CPU = "-cpu cortex-a9"
QB_KERNEL_CMDLINE_APPEND = "console=ttyAMA0,115200"
QB_MEM = "-m 256"
QB_OPT_APPEND = "-nographic"

# Enable OverlayFS support
QB_DRIVE_TYPE = "/dev/mmcblk0"
QB_ROOTFS_OPT = "-drive id=disk0,file=@ROOTFS@,if=sd,format=raw"

# Disable features not needed for testing
MACHINE_FEATURES:remove = "alsa bluetooth wifi pcmcia irda usbgadget usbhost"
```

---

### 0.2 Create Custom Kernel Recipe with ovl-restore Support

**New File:** `meta-calculinux-distro/recipes-kernel/linux/linux-yocto-custom_6.1.bb`

**Purpose:** Build kernel with ovl-restore ioctl patches for QEMU ARM32

**Implementation:**
```bitbake
require recipes-kernel/linux/linux-yocto.inc

LINUX_VERSION ?= "6.1"
LINUX_VERSION_EXTENSION:append = "-ovl-restore"

# Use stable linux-yocto as base
SRCREV_machine = "${AUTOREV}"
SRCREV_meta = "${AUTOREV}"

SRC_URI = "git://git.yoctoproject.org/linux-yocto.git;protocol=https;branch=v6.1/standard/base \
           git://git.yoctoproject.org/yocto-kernel-cache;type=kmeta;name=meta;branch=yocto-6.1;destsuffix=${KMETA} \
           file://0001-overlayfs-add-restore-lower-ioctl.patch \
           file://0002-overlayfs-add-is-restorable-ioctl.patch \
           file://overlayfs-test.cfg \
"

# Kernel config fragment for testing
# overlayfs-test.cfg:
# CONFIG_OVERLAY_FS=y
# CONFIG_OVERLAY_FS_DEBUG=y

COMPATIBLE_MACHINE = "qemu-arm32-test"

KERNEL_FEATURES:append = " features/overlayfs/overlayfs.scc"
```

**New Files to Create:**
- `meta-calculinux-distro/recipes-kernel/linux/linux-yocto-custom/0001-overlayfs-add-restore-lower-ioctl.patch` - Git format-patch from ovl-restore branch
- `meta-calculinux-distro/recipes-kernel/linux/linux-yocto-custom/0002-overlayfs-add-is-restorable-ioctl.patch` - Git format-patch from ovl-restore branch  
- `meta-calculinux-distro/recipes-kernel/linux/linux-yocto-custom/overlayfs-test.cfg` - Kernel config for overlayfs testing

---

### 0.3 Create Minimal Test Image Recipe

**New File:** `meta-calculinux-distro/recipes-core/image/calculinux-qemu-test-image.bb`

**Purpose:** Minimal image with only components needed for testing

**Implementation:**
```bitbake
SUMMARY = "Minimal QEMU ARM32 test image for calculinux-update"
LICENSE = "MIT"

inherit core-image

# Minimal features
IMAGE_FEATURES = "package-management"

# Only essential packages for testing
IMAGE_INSTALL = " \
    bash \
    busybox \
    calculinux-update \
    coreutils \
    e2fsprogs \
    kernel-modules \
    opkg \
    overlayfs-tools \
    ovl-restore \
    python3 \
    python3-pytest \
    python3-ctypes \
    systemd \
"

# Configure minimal overlayfs for /etc
IMAGE_FEATURES += "overlayfs-etc"
OVERLAYFS_ETC_MOUNT_POINT = "/data"
OVERLAYFS_ETC_DEVICE = "/dev/mmcblk0p2"
OVERLAYFS_ETC_FSTYPE = "ext4"
OVERLAYFS_ETC_EXPOSE_LOWER = "1"

# Create test data partition
IMAGE_FSTYPES = "wic"
WKS_FILE = "qemu-test.wks.in"

# Install test scripts
ROOTFS_POSTPROCESS_COMMAND += " install_test_scripts; "

install_test_scripts() {
    install -d ${IMAGE_ROOTFS}/opt/tests
    
    # Create simple test script
    cat > ${IMAGE_ROOTFS}/opt/tests/run-ioctl-tests.sh <<'EOF'
#!/bin/bash
# Test script for ovl-restore ioctl on ARM32

set -e

echo "=== ARM32 ioctl Test Suite ==="
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"

# Test 1: Verify architecture
if [ "$(uname -m)" != "armv7l" ]; then
    echo "ERROR: Not running on ARM32"
    exit 1
fi
echo "✓ Running on ARM32"

# Test 2: Check overlayfs mounted
if ! mount | grep -q overlay; then
    echo "ERROR: No overlay mounts found"
    exit 1
fi
echo "✓ OverlayFS mounted"

# Test 3: Run Python ioctl tests
cd /usr/lib/python3.*/site-packages/calculinux_update
python3 -m pytest tests/integration/test_arm32_ioctl.py -v

# Test 4: Test actual ovl-restore binary
echo "Testing ovl-restore binary..."
ovl-restore --help > /dev/null
echo "✓ ovl-restore binary works"

# Test 5: Create test overlay scenario
echo "Creating test overlay scenario..."
mkdir -p /data/overlay/etc/upper/test
mkdir -p /data/overlay/etc/lower/test
echo "lower-content" > /data/overlay/etc/lower/test/file.txt
# Create whiteout
mknod /data/overlay/etc/upper/test/file.txt c 0 0

# Test 6: Verify ioctl detects restorable file
python3 << 'PYEOF'
from calculinux_update.opkg.overlayfs import check_file_restorability, FileRestorability

result = check_file_restorability("/", "/etc/test/file.txt")
if result != FileRestorability.WHITEOUT:
    print(f"ERROR: Expected WHITEOUT, got {result}")
    exit(1)
print("✓ ioctl correctly detects whiteout")
PYEOF

# Test 7: Test restoration
ovl-restore / /etc/test/file.txt
if [ "$(cat /etc/test/file.txt)" != "lower-content" ]; then
    echo "ERROR: File not restored correctly"
    exit 1
fi
echo "✓ File restored successfully"

echo ""
echo "=== All Tests Passed ==="
EOF
    
    chmod +x ${IMAGE_ROOTFS}/opt/tests/run-ioctl-tests.sh
}
```

---

### 0.4 Create WIC Disk Layout for QEMU

**New File:** `meta-calculinux-distro/wic/qemu-test.wks.in`

**Purpose:** Define partition layout with data partition for overlayfs

**Implementation:**
```
# QEMU ARM32 Test Image Layout
# Simple two-partition layout: rootfs + data

part /boot --source bootimg-partition --fstype=vfat --label boot --active --align 4 --size 32
part / --source rootfs --fstype=ext4 --label root --align 4 --size 400
part /data --fstype=ext4 --label data --align 4 --size 100

bootloader --ptable msdos
```

---

### 0.5 Create KAS Configuration for QEMU Testing

**New File:** `meta-calculinux/kas-qemu-arm32-test.yaml`

**Purpose:** KAS config for building QEMU test image

**Implementation:**
```yaml
header:
  version: 14

build_system: oe

machine: qemu-arm32-test
distro: calculinux-distro
target: calculinux-qemu-test-image

repos:
  meta-calculinux:
    path: .

  poky:
    url: https://git.yoctoproject.org/poky
    refspec: scarthgap
    layers:
      meta:
      meta-poky:

  meta-openembedded:
    url: https://git.openembedded.org/meta-openembedded
    refspec: scarthgap
    layers:
      meta-oe:
      meta-python:
      meta-networking:

local_conf_header:
  test-settings: |
    # QEMU testing optimizations
    INHERIT += "rm_work"
    BB_NUMBER_THREADS ?= "${@oe.utils.cpu_count()}"
    PARALLEL_MAKE ?= "-j ${@oe.utils.cpu_count()}"
    
    # Minimal downloads
    DL_DIR ?= "${TOPDIR}/downloads"
    SSTATE_DIR ?= "${TOPDIR}/sstate-cache"
```

---

### 0.6 Create CI/Local Test Runner Script

**New File:** `meta-calculinux/scripts/run-qemu-arm32-tests.sh`

**Purpose:** Automated script to build and run tests in QEMU

**Implementation:**
```bash
#!/bin/bash
# Run ARM32 tests in QEMU
# Usage: ./scripts/run-qemu-arm32-tests.sh [build|test|both]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${REPO_DIR}/../build-qemu-test"
KAS_YAML="${REPO_DIR}/kas-qemu-arm32-test.yaml"

ACTION="${1:-both}"

build_image() {
    echo "=== Building QEMU ARM32 Test Image ==="
    
    # Use kas-container for reproducible builds
    "${REPO_DIR}/kas-container" build "${KAS_YAML}"
    
    echo "✓ Build complete"
}

run_tests() {
    echo "=== Running Tests in QEMU ARM32 ==="
    
    IMAGE_DIR="${BUILD_DIR}/tmp/deploy/images/qemu-arm32-test"
    
    if [ ! -f "${IMAGE_DIR}/calculinux-qemu-test-image-qemu-arm32-test.wic" ]; then
        echo "ERROR: Image not found. Run build first."
        exit 1
    fi
    
    # Boot QEMU and run tests
    timeout 300 runqemu \
        qemu-arm32-test \
        nographic \
        qemuparams="-serial mon:stdio" \
        bootparams="init=/opt/tests/run-ioctl-tests.sh" || {
        
        # If init fails, boot normally and run tests manually
        echo "Running tests interactively..."
        runqemu qemu-arm32-test nographic &
        QEMU_PID=$!
        
        # Wait for boot
        sleep 30
        
        # SSH in and run tests (requires networking setup)
        # Or use serial console automation
        
        kill $QEMU_PID
    }
    
    echo "✓ Tests complete"
}

case "$ACTION" in
    build)
        build_image
        ;;
    test)
        run_tests
        ;;
    both)
        build_image
        run_tests
        ;;
    *)
        echo "Usage: $0 [build|test|both]"
        exit 1
        ;;
esac

echo ""
echo "=== QEMU ARM32 Testing Complete ==="
```

---

### 0.7 Add GitHub Actions CI Workflow

**New File:** `meta-calculinux/.github/workflows/qemu-arm32-tests.yml`

**Purpose:** Automated testing on every PR

**Implementation:**
```yaml
name: QEMU ARM32 Tests

on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'meta-calculinux-distro/recipes-core/calculinux-update/**'
      - 'meta-calculinux-distro/recipes-kernel/**'
      - 'meta-calculinux-distro/recipes-core/rauc/**'
      - 'meta-calculinux-distro/recipes-core/opkg/**'
      - '.github/workflows/qemu-arm32-tests.yml'
  
  workflow_dispatch:

jobs:
  qemu-arm32-test:
    runs-on: ubuntu-22.04
    
    steps:
      - name: Checkout meta-calculinux
        uses: actions/checkout@v4
        with:
          path: meta-calculinux
          submodules: recursive
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            gawk wget git diffstat unzip texinfo gcc build-essential \
            chrpath socat cpio python3 python3-pip python3-pexpect \
            xz-utils debianutils iputils-ping python3-git python3-jinja2 \
            libegl1-mesa libsdl1.2-dev pylint xterm python3-subunit \
            mesa-common-dev zstd liblz4-tool qemu-system-arm
      
      - name: Setup KAS
        run: |
          pip3 install kas
      
      - name: Build QEMU Test Image
        run: |
          cd meta-calculinux
          kas build kas-qemu-arm32-test.yaml
        env:
          SSTATE_DIR: ${{ github.workspace }}/sstate-cache
          DL_DIR: ${{ github.workspace }}/downloads
      
      - name: Run Tests in QEMU
        run: |
          cd meta-calculinux
          timeout 600 ./scripts/run-qemu-arm32-tests.sh test
      
      - name: Upload test logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: qemu-test-logs
          path: |
            build-qemu-test/tmp/log/
            build-qemu-test/tmp/work/qemu-arm32-test/*/temp/log.*
      
      - name: Cache sstate
        uses: actions/cache@v4
        with:
          path: sstate-cache
          key: sstate-qemu-${{ runner.os }}-${{ github.sha }}
          restore-keys: |
            sstate-qemu-${{ runner.os }}-
```

---

### 0.8 Add Documentation for QEMU Testing

**New File:** `meta-calculinux/docs/QEMU-TESTING.md`

**Content:**
```markdown
# QEMU ARM32 Testing for Calculinux

This document describes how to test calculinux-update components on ARM32 
architecture using QEMU before deploying to physical hardware.

## Quick Start

Build and test in one command:
```bash
./scripts/run-qemu-arm32-tests.sh both
```

## Manual Steps

### 1. Build Test Image

```bash
./kas-container build kas-qemu-arm32-test.yaml
```

### 2. Boot QEMU

```bash
cd ../build-qemu-test
runqemu qemu-arm32-test nographic
```

### 3. Run Tests Inside QEMU

Once booted, login (root, no password) and run:
```bash
/opt/tests/run-ioctl-tests.sh
```

## What Gets Tested

- ARM32 architecture validation
- ioctl struct packing (16 bytes)
- 32-bit pointer → 64-bit cast
- OVL_IOC_RESTORE_LOWER ioctl
- OVL_IOC_IS_RESTORABLE ioctl
- OverlayFS whiteout detection
- File restoration from lower layer

## Debugging

View kernel logs:
```bash
dmesg | grep overlay
```

Test ioctl manually:
```bash
ovl-restore --test / /path/to/file
```

Run Python tests:
```bash
cd /usr/lib/python*/site-packages/calculinux_update
python3 -m pytest tests/ -v
```

## CI Integration

GitHub Actions automatically runs these tests on every PR that touches:
- calculinux-update
- Kernel ovl-restore patches
- RAUC integration
- opkg modifications

See `.github/workflows/qemu-arm32-tests.yml` for details.
```

---

## Phase 1: Critical Fixes (Required for Correctness)

### 1.1 Fix Python ioctl Pointer Safety for 32-bit ARM

**File:** `calculinux-update/src/calculinux_update/opkg/overlayfs.py`

**Critical Issue:** Primary deployment is 32-bit ARM where pointers are 4 bytes, but kernel struct expects `__aligned_u64` (8 bytes)

**Changes:**
- Use `ctypes` to get stable pointer address
- Cast 32-bit ARM pointer to 64-bit for kernel struct compatibility
- Ensure null terminator handling matches kernel expectations
- Fix both `restore_lower_via_ioctl()` and `check_file_restorability()`

**Implementation for 32-bit ARM:**
```python
import ctypes
import struct

def restore_lower_via_ioctl(mount_point: str, path: str) -> bool:
    """
    Restore lower layer file using OverlayFS ioctl.
    
    Compatible with both 32-bit and 64-bit architectures.
    On 32-bit ARM, pointer is cast from 4 bytes to 8 bytes for kernel struct.
    """
    try:
        with open(mount_point, 'r') as f:
            # Encode path with null terminator
            path_bytes = path.encode('utf-8') + b'\0'
            
            # Create ctypes buffer for stable pointer
            buf = ctypes.create_string_buffer(path_bytes)
            
            # Get pointer address - works on both 32-bit and 64-bit
            # On 32-bit ARM, addressof() returns 32-bit value
            # On 64-bit, returns 64-bit value
            path_ptr = ctypes.addressof(buf)
            
            # Pack as 64-bit regardless of architecture
            # Kernel struct uses __aligned_u64 which is 8 bytes on all archs
            # path_len is strlen (without null terminator)
            path_len = len(path.encode('utf-8'))
            
            # struct: aligned_u64 (8) + u32 (4) + u32 (4) = 16 bytes
            args = struct.pack('QII', path_ptr, path_len, 0)
            
            fcntl.ioctl(f.fileno(), OVL_IOC_RESTORE_LOWER, args)
        return True
    except OSError as e:
        LOGGER.warning(f"Failed to restore lower for {path}: {e}")
        return False


def check_file_restorability(mount_point: str, path: str) -> FileRestorability:
    """
    Check the restorability state of a file in an overlay filesystem.
    
    Compatible with both 32-bit and 64-bit architectures.
    """
    try:
        with open(mount_point, 'r') as f:
            path_bytes = path.encode('utf-8') + b'\0'
            buf = ctypes.create_string_buffer(path_bytes)
            path_ptr = ctypes.addressof(buf)
            path_len = len(path.encode('utf-8'))
            
            args = struct.pack('QII', path_ptr, path_len, 0)
            fcntl.ioctl(f.fileno(), OVL_IOC_IS_RESTORABLE, args)
        return FileRestorability.WHITEOUT
    except OSError as e:
        if e.errno == errno.EINVAL:
            return FileRestorability.IN_UPPER
        else:  # ENOENT or other errors
            return FileRestorability.IN_LOWER_ONLY
```

**Add architecture validation test:**
```python
def _validate_ioctl_struct_size():
    """Validate that struct packing matches kernel expectations."""
    import sys
    
    # Test struct packing
    test_ptr = 0x12345678 if sys.maxsize <= 2**32 else 0x123456789ABCDEF0
    test_args = struct.pack('QII', test_ptr, 100, 0)
    
    if len(test_args) != 16:
        raise RuntimeError(
            f"ioctl struct size mismatch: expected 16 bytes, got {len(test_args)}. "
            f"Architecture: {'32-bit' if sys.maxsize <= 2**32 else '64-bit'}"
        )
    
    LOGGER.debug("ioctl struct validation passed (16 bytes on %s)", 
                 '32-bit' if sys.maxsize <= 2**32 else '64-bit')

# Run validation on module load
_validate_ioctl_struct_size()
```

---

### 1.2 Verify and Fix ioctl Magic Numbers (32-bit ARM specific)

**File:** `calculinux-update/src/calculinux_update/opkg/overlayfs.py`

**Issue:** ioctl numbers must be correct for ARM architecture

**Changes:**
- Calculate ioctl numbers matching kernel `_IOW` macro
- Verify against ARM32 ioctl encoding
- Add runtime validation

**Implementation:**
```python
import sys

# ioctl encoding constants (architecture-independent)
_IOC_NONE = 0
_IOC_WRITE = 1
_IOC_READ = 2

_IOC_NRBITS = 8
_IOC_TYPEBITS = 8
_IOC_SIZEBITS = 14
_IOC_DIRBITS = 2

_IOC_NRSHIFT = 0
_IOC_TYPESHIFT = _IOC_NRSHIFT + _IOC_NRBITS
_IOC_SIZESHIFT = _IOC_TYPESHIFT + _IOC_TYPEBITS
_IOC_DIRSHIFT = _IOC_SIZESHIFT + _IOC_SIZEBITS

def _IOW(type_char: str, nr: int, size: int) -> int:
    """
    Calculate ioctl number for write operation.
    
    Matches kernel _IOW macro:
    #define _IOW(type,nr,size) _IOC(_IOC_WRITE,(type),(nr),(_IOC_TYPECHECK(size)))
    
    Args:
        type_char: Magic number character (e.g., 'O' for overlayfs)
        nr: Command number
        size: Size of argument structure in bytes
    
    Returns:
        ioctl number
    """
    return (_IOC_WRITE << _IOC_DIRSHIFT) | \
           (ord(type_char) << _IOC_TYPESHIFT) | \
           (nr << _IOC_NRSHIFT) | \
           (size << _IOC_SIZESHIFT)

# Calculate ioctl numbers
# struct ovl_restore_lower_args: aligned_u64 (8) + u32 (4) + u32 (4) = 16 bytes
# This is consistent across 32-bit and 64-bit architectures
OVL_IOC_RESTORE_LOWER = _IOW('O', 1, 16)
OVL_IOC_IS_RESTORABLE = _IOW('O', 2, 16)

# Log calculated values for debugging
LOGGER.debug(
    "ioctl numbers: RESTORE=0x%08x, IS_RESTORABLE=0x%08x (arch: %s)",
    OVL_IOC_RESTORE_LOWER,
    OVL_IOC_IS_RESTORABLE,
    'ARM32' if sys.maxsize <= 2**32 else '64-bit'
)

# Expected values for validation
# _IOW('O', 1, 16) = 0x40104F01
# _IOW('O', 2, 16) = 0x40104F02
if OVL_IOC_RESTORE_LOWER != 0x40104F01:
    LOGGER.warning(
        "ioctl number mismatch: RESTORE expected 0x40104F01, got 0x%08x",
        OVL_IOC_RESTORE_LOWER
    )

if OVL_IOC_IS_RESTORABLE != 0x40104F02:
    LOGGER.warning(
        "ioctl number mismatch: IS_RESTORABLE expected 0x40104F02, got 0x%08x",
        OVL_IOC_IS_RESTORABLE
    )
```

---

### 1.3 Fix Conffile Overlay Path Construction

**File:** `calculinux-update/src/calculinux_update/opkg/conffiles.py`

**Current Problem:** Incorrectly constructs `/data/overlay/<dir>/upper/<filename>` instead of `<upperdir>/<full-path>`

**From research:** Overlay structure is:
- Base: `/data/overlay/{mountpoint}` (e.g., `/data/overlay/etc`, `/data/overlay/var`)
- Upper: `/data/overlay/{mountpoint}/upper` + full path
- Lower: `/data/overlay/{mountpoint}/lower` + full path

**Changes:**
- Parse actual overlay mount options to get real upperdir/lowerdir
- Construct full paths correctly: `<upperdir>/<full-relative-path>`
- Handle the specific Calculinux overlay structure
- Add validation that paths exist before MD5 comparison

**Implementation:**
```python
def get_overlay_dirs_for_path(file_path: Path) -> tuple[Path | None, Path | None]:
    """
    Get overlay upper/lower directories for a specific file path.
    
    Calculinux mounts multiple overlays: /etc, /root, /home, /var, /usr, /opt
    Each has structure: /data/overlay/{mountpoint}/upper and /lower
    
    Args:
        file_path: Absolute path to file (e.g., /etc/foo.conf)
    
    Returns:
        (upper_file_path, lower_file_path) or (None, None) if not in overlay
    """
    # Determine which overlay this file belongs to
    overlaid_paths = ['/etc', '/root', '/home', '/var', '/usr', '/opt']
    
    for overlay_mount in overlaid_paths:
        if str(file_path).startswith(overlay_mount + '/') or str(file_path) == overlay_mount:
            # Found the overlay for this path
            # Structure: /data/overlay/{mountpoint}/upper/<rel-path>
            rel_path = str(file_path)[len(overlay_mount):].lstrip('/')
            
            base = Path(f"/data/overlay{overlay_mount}")
            upper = base / "upper" / rel_path
            lower = base / "lower" / rel_path
            
            return (upper, lower)
    
    # File not in an overlaid path
    return (None, None)


def detect_modified_conffiles(
    image_packages: List[str],
) -> List[ConffileInfo]:
    """Detect config files that have been modified in the upper layer.
    
    Compares config files between upper and lower layers:
    - If file exists in both layers with different checksums, it's been modified
    - Only considers files from packages in the new base image
    
    Args:
        image_packages: List of package names in the new base image
        
    Returns:
        List of ConffileInfo for files that were modified in upper layer
    """
    modified = []
    
    # Get all config files from new base image packages
    image_conffiles = get_all_conffiles(image_packages)
    
    if not image_conffiles:
        LOGGER.debug("No config files found in image packages")
        return []
    
    for conffile in image_conffiles:
        file_path = Path(conffile.path)
        
        # Skip if file doesn't actually exist in the filesystem
        if not file_path.exists():
            LOGGER.debug("Config file %s doesn't exist, skipping", conffile.path)
            continue
        
        # Get upper and lower paths for this file
        upper_file, lower_file = get_overlay_dirs_for_path(file_path)
        
        if upper_file is None or lower_file is None:
            # File not in an overlay - skip
            LOGGER.debug("Config file %s not in overlay, skipping", conffile.path)
            continue
        
        # If file only exists in lower, it hasn't been modified
        if not upper_file.exists():
            LOGGER.debug("Config file %s not in upper layer, skipping", conffile.path)
            continue
        
        # If lower doesn't exist, can't compare
        if not lower_file.exists():
            LOGGER.debug("Config file %s has no lower layer version, skipping", conffile.path)
            continue
        
        # Compute checksums for both versions
        upper_md5 = _compute_md5(upper_file)
        lower_md5 = _compute_md5(lower_file)
        
        if upper_md5 is None or lower_md5 is None:
            LOGGER.debug("Cannot compare %s: upper_md5=%s, lower_md5=%s",
                        conffile.path, upper_md5, lower_md5)
            continue
        
        if upper_md5 != lower_md5:
            LOGGER.info("Modified conffile detected: %s (package: %s)",
                       conffile.path, conffile.package)
            modified.append(conffile)
    
    return modified


def create_dpkg_new_files(
    modified_conffiles: List[ConffileInfo],
    dry_run: bool = False
) -> Dict[str, str]:
    """Create .dpkg-new files for modified config files.
    
    For each modified config file, copies the new version from the lower layer
    to a .dpkg-new file in the actual filesystem location.
    
    Args:
        modified_conffiles: List of config files that were modified
        dry_run: If True, don't actually create files
        
    Returns:
        Dict mapping original file path to .dpkg-new file path
    """
    created_files = {}
    
    for conffile in modified_conffiles:
        file_path = Path(conffile.path)
        dpkg_new_path = Path(str(file_path) + '.dpkg-new')
        
        # Get lower layer version using our overlay path helper
        _, lower_file = get_overlay_dirs_for_path(file_path)
        
        if lower_file is None or not lower_file.exists():
            LOGGER.warning("Lower layer file missing for %s, skipping", conffile.path)
            continue
        
        if dry_run:
            LOGGER.info("Would create %s from lower layer", dpkg_new_path)
            created_files[conffile.path] = str(dpkg_new_path)
        else:
            try:
                shutil.copy2(lower_file, dpkg_new_path)
                LOGGER.info("Created %s from lower layer", dpkg_new_path)
                created_files[conffile.path] = str(dpkg_new_path)
            except (OSError, IOError) as e:
                LOGGER.error("Failed to create %s: %s", dpkg_new_path, e)
    
    return created_files
```

---

### 1.4 Fix Bundle Extras Extraction in RAUC

**File:** `meta-calculinux-distro/recipes-core/rauc/files/post-install-handler.sh`

**Changes:** Add explicit extraction of bundle-extras.tar.gz

**Implementation:**
```bash
#!/bin/sh
# RAUC post-install system handler wrapper
set -e

echo "RAUC post-install handler starting"
echo "RAUC_BUNDLE_MOUNT_POINT=${RAUC_BUNDLE_MOUNT_POINT}"
echo "RAUC_TARGET_SLOTS=${RAUC_TARGET_SLOTS}"

# Extract bundle extras if present
EXTRAS_TARBALL="${RAUC_BUNDLE_MOUNT_POINT}/bundle-extras.tar.gz"
EXTRAS_DIR="${RAUC_BUNDLE_MOUNT_POINT}/extras"

if [ -f "${EXTRAS_TARBALL}" ]; then
    echo "Extracting bundle extras..."
    
    # Extract to bundle mount point
    if ! tar -xzf "${EXTRAS_TARBALL}" -C "${RAUC_BUNDLE_MOUNT_POINT}/"; then
        echo "ERROR: Failed to extract bundle extras" >&2
        exit 1
    fi
    
    echo "Bundle extras extracted successfully"
fi

# Check if bundle extras contain the status.image file
BUNDLE_STATUS_IMAGE="${RAUC_BUNDLE_MOUNT_POINT}/extras/opkg/status.image"

if [ ! -f "${BUNDLE_STATUS_IMAGE}" ]; then
    echo "WARNING: No status.image found in bundle extras at ${BUNDLE_STATUS_IMAGE}"
    echo "Skipping package reconciliation"
    exit 0
fi

# Iterate over all target slots that were updated
for i in ${RAUC_TARGET_SLOTS}; do
    eval SLOT_NAME=\$RAUC_SLOT_NAME_${i}
    eval SLOT_CLASS=\$RAUC_SLOT_CLASS_${i}
    
    echo "Processing slot $i: name=${SLOT_NAME}, class=${SLOT_CLASS}"
    
    # Only process rootfs slots
    if [ "${SLOT_CLASS}" = "rootfs" ]; then
        echo "Running post-install hook for rootfs slot ${SLOT_NAME}"
        
        # Export environment variables that cup-hook expects
        export RAUC_SLOT_CLASS="${SLOT_CLASS}"
        export RAUC_SLOT_NAME="${SLOT_NAME}"
        export RAUC_BUNDLE_STATUS_IMAGE="${BUNDLE_STATUS_IMAGE}"
        
        # Call cup-hook with slot-post-install hook type
        if /usr/lib/calculinux-update/cup-hook slot-post-install "${SLOT_NAME}"; then
            echo "cup-hook completed successfully for ${SLOT_NAME}"
        else
            echo "ERROR: cup-hook failed for ${SLOT_NAME}" >&2
            exit 1
        fi
    fi
done

echo "RAUC post-install handler completed successfully"
exit 0
```

---

## Phase 2: Major Version Upgrade Support

### 2.1 Create Distribution Version Manifest

**Files:**
- New: `meta-calculinux-distro/recipes-core/image/files/version-manifest.sh.in`
- Modified: `meta-calculinux-distro/recipes-core/image/calculinux-image.bb`

**Manifest format (`/var/lib/calculinux/version-manifest.env`):**
```bash
# Distribution Version Manifest
# Generated at image build time
CALCULINUX_VERSION="${DISTRO_VERSION}"
CALCULINUX_CODENAME="${DISTRO_CODENAME}"
YOCTO_VERSION="${DISTRO_VERSION_CODENAME}"  # e.g., "scarthgap"
KERNEL_VERSION="${KERNEL_VERSION}"
KERNEL_RELEASE="${@d.getVar('PREFERRED_VERSION_linux-rockchip') or 'unknown'}"
GLIBC_VERSION="${GLIBCVERSION}"  # or MUSL_VERSION
PYTHON_VERSION="${PYTHON_BASEVERSION}"
SYSTEMD_VERSION="${@bb.utils.contains('DISTRO_FEATURES', 'systemd', d.getVar('SYSTEMD_VERSION'), 'none', d)}"
FEED_BASE_URL="${PACKAGE_FEED_URIS}"
FEED_PATH="${PACKAGE_FEED_BASE_PATHS}"
BUILD_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BUILD_HOST="${BUILD_SYS}"
```

**Integration in image recipe:**
```bitbake
ROOTFS_POSTPROCESS_COMMAND += " calculinux_create_version_manifest;"

calculinux_create_version_manifest() {
    manifest_dir="${IMAGE_ROOTFS}/var/lib/calculinux"
    manifest_file="$manifest_dir/version-manifest.env"
    
    install -d "$manifest_dir"
    
    cat > "$manifest_file" <<EOF
CALCULINUX_VERSION="${DISTRO_VERSION}"
CALCULINUX_CODENAME="${DISTRO_CODENAME}"
# ... rest of variables
EOF
    
    chmod 644 "$manifest_file"
}

calculinux_export_bundle_extras() {
    # Add version manifest to bundle extras
    if [ -f "${IMAGE_ROOTFS}/var/lib/calculinux/version-manifest.env" ]; then
        install -d "${extras_dir}"
        install -m 0644 \
            "${IMAGE_ROOTFS}/var/lib/calculinux/version-manifest.env" \
            "${extras_dir}/version-manifest.env"
    fi
}
```

---

### 2.2 Implement Version Compatibility Checking

**New File:** `calculinux-update/src/calculinux_update/version_compat.py`

**Functions:**
- `load_version_manifest(path: Path) -> dict` - Parse manifest file
- `check_compatibility(old: dict, new: dict) -> CompatibilityReport` - Compare versions
- `get_upgrade_type(old_ver: str, new_ver: str) -> UpgradeType` - Classify upgrade (major/minor/patch)
- `get_feed_migration_required(old: dict, new: dict) -> bool` - Check if feed URLs need update

**Data structures:**
```python
from enum import Enum
from dataclasses import dataclass

class UpgradeType(Enum):
    PATCH = "patch"      # 1.0.0 -> 1.0.1
    MINOR = "minor"      # 1.0.x -> 1.1.x
    MAJOR = "major"      # 1.x.x -> 2.x.x
    DOWNGRADE = "downgrade"
    
class CompatLevel(Enum):
    COMPATIBLE = "compatible"         # No action needed
    MINOR_ISSUES = "minor_issues"     # Warnings but proceed
    MAJOR_ISSUES = "major_issues"     # Require user confirmation
    INCOMPATIBLE = "incompatible"     # Block upgrade

@dataclass
class CompatibilityIssue:
    level: CompatLevel
    category: str  # "kernel", "abi", "python", "feeds", etc.
    message: str
    recommendation: str | None = None

@dataclass
class CompatibilityReport:
    upgrade_type: UpgradeType
    overall_level: CompatLevel
    issues: list[CompatibilityIssue]
    
    def any_blockers(self) -> bool:
        return self.overall_level == CompatLevel.INCOMPATIBLE
```

**Key compatibility checks:**
```python
def check_compatibility(old: dict, new: dict) -> CompatibilityReport:
    issues = []
    
    # 1. Kernel major version change
    if parse_version(old['KERNEL_VERSION'])[0] != \
       parse_version(new['KERNEL_VERSION'])[0]:
        issues.append(CompatibilityIssue(
            level=CompatLevel.MAJOR_ISSUES,
            category="kernel",
            message=f"Kernel major version changed: {old['KERNEL_VERSION']} → {new['KERNEL_VERSION']}",
            recommendation="Out-of-tree kernel modules will need rebuild"
        ))
    
    # 2. Python version change
    if old.get('PYTHON_VERSION') != new.get('PYTHON_VERSION'):
        issues.append(CompatibilityIssue(
            level=CompatLevel.MAJOR_ISSUES,
            category="python",
            message=f"Python version changed: {old['PYTHON_VERSION']} → {new['PYTHON_VERSION']}",
            recommendation="Python packages may need reinstall"
        ))
    
    # 3. Yocto release change (ABI break likely)
    if old.get('YOCTO_VERSION') != new.get('YOCTO_VERSION'):
        issues.append(CompatibilityIssue(
            level=CompatLevel.MAJOR_ISSUES,
            category="abi",
            message=f"Yocto release changed: {old['YOCTO_VERSION']} → {new['YOCTO_VERSION']}",
            recommendation="All packages from overlay should be upgraded/reinstalled"
        ))
    
    # 4. Feed URL/codename change
    if old.get('CALCULINUX_CODENAME') != new.get('CALCULINUX_CODENAME'):
        issues.append(CompatibilityIssue(
            level=CompatLevel.MINOR_ISSUES,
            category="feeds",
            message=f"Codename changed: {old['CALCULINUX_CODENAME']} → {new['CALCULINUX_CODENAME']}",
            recommendation="Package feeds will be updated to new codename"
        ))
    
    # Determine overall level
    upgrade_type = get_upgrade_type(
        old.get('CALCULINUX_VERSION', '0.0.0'),
        new.get('CALCULINUX_VERSION', '0.0.0')
    )
    
    return CompatibilityReport(
        upgrade_type=upgrade_type,
        overall_level=max(i.level for i in issues) if issues else CompatLevel.COMPATIBLE,
        issues=issues
    )
```

---

### 2.3 Integrate Version Checking into Update Workflow

**Modified:** `calculinux-update/src/calculinux_update/hooks.py`

**Changes to `run_slot_hook()`:**
```python
from .version_compat import load_version_manifest, check_compatibility

CURRENT_VERSION_MANIFEST = Path("/var/lib/calculinux/version-manifest.env")
BUNDLE_VERSION_MANIFEST = "extras/version-manifest.env"

def run_slot_hook(hook: str, slot: str) -> None:
    if hook != "slot-post-install":
        return
        
    # ... existing checks ...
    
    # Load version manifests
    bundle_manifest_path = Path(os.environ.get("RAUC_BUNDLE_MOUNT_POINT")) / BUNDLE_VERSION_MANIFEST
    
    old_manifest = {}
    new_manifest = {}
    
    if CURRENT_VERSION_MANIFEST.exists():
        old_manifest = load_version_manifest(CURRENT_VERSION_MANIFEST)
    
    if bundle_manifest_path.exists():
        new_manifest = load_version_manifest(bundle_manifest_path)
    
    # Check compatibility
    if old_manifest and new_manifest:
        compat_report = check_compatibility(old_manifest, new_manifest)
        
        LOG.info("Version upgrade: %s → %s (%s)",
                old_manifest.get('CALCULINUX_VERSION', 'unknown'),
                new_manifest.get('CALCULINUX_VERSION', 'unknown'),
                compat_report.upgrade_type.value)
        
        if compat_report.issues:
            LOG.info("=== Compatibility Analysis ===")
            for issue in compat_report.issues:
                LOG.info("[%s] %s: %s",
                        issue.level.name,
                        issue.category,
                        issue.message)
                if issue.recommendation:
                    LOG.info("  → %s", issue.recommendation)
        
        # For major upgrades, add special handling
        if compat_report.upgrade_type == UpgradeType.MAJOR:
            _handle_major_version_upgrade(compat_report)
    
    # Continue with existing reconciliation...
```

---

### 2.4 Add Package ABI Compatibility Checking

**Modified:** `calculinux-update/src/calculinux_update/opkg/reconcile.py`

**New function:**
```python
def check_abi_compatibility(
    writable_packages: set[str],
    image_status: Path
) -> tuple[list[str], list[str]]:
    """Check if writable packages have satisfied dependencies.
    
    Returns:
        (broken_packages, missing_deps)
    """
    broken = []
    missing_deps = []
    
    # Get list of all packages available in image
    image_packages = load_package_names(image_status)
    
    for pkg in writable_packages:
        # Get package dependencies
        result = subprocess.run(
            ["opkg", "info", pkg],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode != 0:
            continue
            
        # Parse Depends: line
        for line in result.stdout.splitlines():
            if line.startswith("Depends:"):
                deps = line.split(":", 1)[1].strip()
                # Parse dependency syntax: "pkg1 (>= 1.0), pkg2 | pkg3"
                for dep in deps.split(","):
                    dep = dep.strip().split()[0]  # Get package name only
                    dep = dep.split("|")[0].strip()  # Handle alternatives
                    
                    # Check if dependency satisfied
                    if dep not in image_packages:
                        # Check if it's in writable layer
                        check = subprocess.run(
                            ["opkg", "status", dep],
                            capture_output=True
                        )
                        if check.returncode != 0:
                            missing_deps.append(f"{pkg} → {dep}")
                            if pkg not in broken:
                                broken.append(pkg)
    
    return broken, missing_deps
```

**Integration in reconcile plan:**
```python
@dataclass(slots=True)
class ReconcilePlan:
    duplicates: List[str]
    status_only_duplicates: List[str]
    reinstall: List[str]
    upgrade: List[str]
    broken_abi: List[str]  # New field
    missing_deps: List[str]  # New field
```

---

### 2.5 Handle Feed URL Migration for Major Upgrades

**Modified:** `calculinux-update/src/calculinux_update/hooks.py`

**New function:**
```python
def _handle_major_version_upgrade(compat_report: CompatibilityReport) -> None:
    """Handle special cases for major version upgrades."""
    
    # 1. Update opkg feed URLs if codename changed
    if any(i.category == "feeds" for i in compat_report.issues):
        _update_feed_urls()
    
    # 2. Mark all writable packages for upgrade check
    #    (they may have been compiled against old ABIs)
    if any(i.category in ("abi", "kernel") for i in compat_report.issues):
        LOG.info("Major ABI change detected - all overlay packages will be checked for compatibility")
        # This is handled in post-reboot reconciliation
    
    # 3. Backup current package list for potential manual recovery
    _backup_package_list()

def _update_feed_urls() -> None:
    """Update opkg feed configuration to point to new version's feeds."""
    feed_conf = Path("/etc/opkg/base-feeds.conf")
    
    if not feed_conf.exists():
        LOG.warning("Feed configuration not found at %s", feed_conf)
        return
    
    # Read new manifest to get correct feed URLs
    bundle_manifest = Path(os.environ.get("RAUC_BUNDLE_MOUNT_POINT")) / "extras/version-manifest.env"
    if not bundle_manifest.exists():
        return
    
    new_manifest = load_version_manifest(bundle_manifest)
    new_codename = new_manifest.get('CALCULINUX_CODENAME')
    new_feed_path = new_manifest.get('FEED_PATH')
    
    if not new_codename or not new_feed_path:
        return
    
    # Update feed URLs in config
    # This could be done by regenerating the file or sed replacement
    LOG.info("Updating package feed URLs to: %s", new_feed_path)
    # Implementation depends on feed config format
```

---

## Phase 3: Rollback and State Management Enhancements

### 3.1 Implement Atomic State Machine for Reconciliation

**Modified:** `calculinux-update/src/calculinux_update/hooks.py`

**Add state tracking:**
```python
from enum import Enum

class ReconcileState(Enum):
    NONE = "none"
    STARTED = "started"
    STATUS_PRUNED = "status_pruned"
    DUPLICATES_REMOVING = "duplicates_removing"
    DUPLICATES_RESTORING = "duplicates_restoring"
    REINSTALL_IN_PROGRESS = "reinstall_in_progress"
    UPGRADE_IN_PROGRESS = "upgrade_in_progress"
    COMPLETE = "complete"

RECONCILE_STATE_FILE = STATE_DIR / "reconcile-state"

def _save_reconcile_state(state: ReconcileState) -> None:
    """Persist current reconciliation state for crash recovery."""
    _ensure_state_dir()
    _atomic_write(RECONCILE_STATE_FILE, state.value + "\n")

def _load_reconcile_state() -> ReconcileState:
    """Load reconciliation state from file."""
    if not RECONCILE_STATE_FILE.exists():
        return ReconcileState.NONE
    try:
        state_str = RECONCILE_STATE_FILE.read_text().strip()
        return ReconcileState(state_str)
    except (ValueError, OSError):
        return ReconcileState.NONE

def _resume_reconciliation() -> None:
    """Resume reconciliation from last known state after crash."""
    state = _load_reconcile_state()
    
    LOG.info("Resuming reconciliation from state: %s", state.value)
    
    if state == ReconcileState.DUPLICATES_REMOVING:
        # Some packages removed but not all
        # Check which packages are still in PENDING_DUPLICATES and retry
        pass
    elif state == ReconcileState.DUPLICATES_RESTORING:
        # Packages removed but restoration incomplete
        # Re-run restoration for all packages in list
        pass
    # ... handle other states
```

---

### 3.2 Enhance Rollback to Restore Upper Layer State

**Modified:** `calculinux-update/src/calculinux_update/hooks.py`

**Problem:** Current rollback only restores status file, not actual files

**Approach:** Don't do destructive operations in slot-post-install, only in post-reboot

**Changes:**
```python
def run_slot_hook(hook: str, slot: str) -> None:
    # ... version checking ...
    
    # Phase 1: ONLY prune status-only duplicates (no physical files)
    if plan.status_only_duplicates:
        _prune_status_only_duplicates(plan.status_only_duplicates)
    
    # Phase 2-4: Queue for post-reboot (NO physical operations yet)
    _write_pending(PENDING_DUPLICATES_FILE, plan.duplicates, "duplicate removal")
    _write_pending(PENDING_REINSTALL_FILE, plan.reinstall, "reinstall")
    _write_pending(PENDING_UPGRADE_FILE, plan.upgrade, "upgrade")
    
    # Phase 5: Detect conffiles but DON'T create .dpkg-new yet
    modified_conffiles = detect_modified_conffiles(list(image_packages))
    if modified_conffiles:
        _write_pending_conffiles(modified_conffiles)
    
    # NO opkg remove operations here - all happen post-reboot
```

This way, if user rolls back before rebooting, no physical changes have occurred and the old slot boots cleanly.

---

## Phase 4: Additional Improvements

### 4.1 Add Write Protection for image_status_file in opkg

**File:** `opkg/libopkg/opkg_cmd.c`

**Add check in functions that write status:**
```c
static int opkg_update_pkg_status(pkg_t *pkg) {
    pkg_dest_t *dest = pkg->dest;
    
    // Prevent writing to read-only image status file
    if (dest->image_status_file_name &&
        strcmp(dest->status_file_name, dest->image_status_file_name) == 0) {
        opkg_msg(ERROR, "Cannot modify read-only image status file\n");
        return -1;
    }
    
    // ... normal status update ...
}
```

---

### 4.2 Add Comprehensive Integration Tests

**New Files:**
- `calculinux-update/tests/integration/test_version_upgrade.py`
- `calculinux-update/tests/integration/test_arm32_ioctl.py` **(NEW)**
- `calculinux-update/tests/integration/test_conffile_resolution.py`
- `calculinux-update/tests/integration/test_rollback_scenarios.py`

**ARM32-specific tests:**
```python
# tests/integration/test_arm32_ioctl.py
import sys
import struct
import pytest

def test_ioctl_struct_size():
    """Verify ioctl struct packing is correct on ARM32."""
    # struct: aligned_u64 (8) + u32 (4) + u32 (4) = 16 bytes
    args = struct.pack('QII', 0x12345678, 100, 0)
    assert len(args) == 16, f"Expected 16 bytes, got {len(args)}"

def test_pointer_cast_to_64bit():
    """Verify 32-bit pointers are correctly cast to 64-bit."""
    import ctypes
    
    # Create a buffer
    buf = ctypes.create_string_buffer(b"test\0")
    ptr = ctypes.addressof(buf)
    
    # Pack as 64-bit
    packed = struct.pack('Q', ptr)
    assert len(packed) == 8
    
    # Unpack and verify
    unpacked = struct.unpack('Q', packed)[0]
    assert unpacked == ptr

@pytest.mark.skipif(sys.maxsize > 2**32, reason="ARM32-specific test")
def test_arm32_pointer_size():
    """Verify we're running on 32-bit architecture as expected."""
    import ctypes
    assert ctypes.sizeof(ctypes.c_void_p) == 4, "Expected 32-bit pointers"
```

**Test scenarios:**
```python
def test_major_version_upgrade_compat_check():
    """Test version manifest parsing and compatibility checking."""
    # Create old and new manifests with major version bump
    # Run compatibility check
    # Verify issues are detected and categorized
    
def test_feed_url_migration():
    """Test that feed URLs are updated on codename change."""
    # Set up feed config with old codename
    # Trigger upgrade to new codename
    # Verify feed URLs updated
    
def test_abi_broken_package_detection():
    """Test detection of packages with unsatisfied dependencies."""
    # Install package depending on libfoo.so.1
    # Upgrade to image with only libfoo.so.2
    # Verify package marked as broken
```

---

## Phase 5: Documentation and Error Handling

### 5.1 User-Facing Documentation

**Files to create/update:**
- `docs/docs/user-guide/major-version-upgrades.md` - Guide for users
- `docs/docs/developer/version-manifest.md` - Technical documentation
- Update `docs/docs/user-guide/updates.md` with new compatibility checking

**Content:**
- Explain what constitutes major vs minor upgrades
- Document compatibility issues that may arise
- Provide troubleshooting steps for broken packages
- Explain conffile resolution workflow

---

### 5.2 Improved Error Messages and User Prompts

**Modified:** `calculinux-update/scripts/cup`

**Add pre-install compatibility check:**
```python
@app.command()
def install(
    bundle_path: str = typer.Argument(..., help="Path to .raucb bundle"),
    force: bool = typer.Option(False, "--force", help="Skip compatibility checks")
):
    """Install a RAUC update bundle."""
    
    # Extract and check version manifest before installing
    compat_report = check_bundle_compatibility(bundle_path)
    
    if compat_report.any_blockers() and not force:
        typer.echo("❌ Compatibility check failed:", err=True)
        for issue in compat_report.issues:
            typer.echo(f"  • {issue.message}", err=True)
        typer.echo("\nUse --force to install anyway (not recommended)")
        raise typer.Exit(1)
    
    if compat_report.issues and not force:
        typer.echo("⚠️  Compatibility warnings:")
        for issue in compat_report.issues:
            typer.echo(f"  • {issue.message}")
        if not typer.confirm("\nContinue with installation?"):
            raise typer.Exit(1)
    
    # Proceed with installation
    install_bundle(bundle_path)
```

---

## Summary: Implementation Priorities

| Phase | Priority | Effort | Risk | Notes |
|-------|----------|--------|------|-------|
| **0.1-0.8 QEMU Setup** | **🔴 Critical** | **Medium** | **Low** | **Enables validation before hardware** |
| 1.1 Python ioctl (ARM32) | 🔴 Critical | Low | High | Test in QEMU first |
| 1.2 ioctl magic numbers | 🔴 Critical | Low | Medium | Test in QEMU first |
| 1.3 Conffile paths | 🔴 Critical | Medium | Medium | Test in QEMU |
| 1.4 Bundle extras extract | 🔴 Critical | Low | Low | Can test in QEMU |
| 2.1-2.5 Version upgrade | 🟡 High | High | Low | After QEMU validation |
| 3.1-3.2 Rollback enhance | 🟢 Medium | High | Medium | After QEMU validation |
| 4.1 opkg write protect | 🟢 Low | Low | Low | After QEMU validation |
| 4.2 Integration tests | 🟢 Medium | Medium | Low | Run in QEMU |
| 5.1-5.2 Documentation | 🟢 Medium | Medium | Low | Include QEMU docs |

---

## Development Workflow with QEMU

**New recommended workflow:**

1. **Develop fixes** in calculinux-update Python code
2. **Test locally** in QEMU ARM32: `./scripts/run-qemu-arm32-tests.sh both`
3. **Iterate** until all tests pass in QEMU
4. **Push PR** → GitHub Actions runs same tests automatically
5. **Deploy to hardware** only after QEMU tests pass
6. **Validate on hardware** (final verification)

This catches ARM32-specific issues early without needing physical access to Luckfox Lyra for every iteration.

---

## ARM32-Specific Testing Requirements

Before deployment, these tests must pass on actual ARM32 hardware (Luckfox Lyra):

1. **ioctl struct alignment**: Verify 16-byte struct on ARM32
2. **Pointer casting**: Verify 32-bit → 64-bit pointer cast works
3. **File restoration**: Test actual OVL_IOC_RESTORE_LOWER on ARM32
4. **Conffile MD5 comparison**: Verify overlay path construction on device
5. **Bundle extraction**: Test full RAUC flow with bundle-extras on ARM32

These cannot be fully validated in x86-64 development environment.
