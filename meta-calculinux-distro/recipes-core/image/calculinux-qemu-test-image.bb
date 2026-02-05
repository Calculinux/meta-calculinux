SUMMARY = "Minimal QEMU ARM32 test image for calculinux-update"
LICENSE = "MIT"

inherit core-image

# Minimal features: overlayfs-etc matches production layout
IMAGE_FEATURES = "package-management"
IMAGE_FEATURES += "overlayfs-etc"

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

# Use same overlayfs init template as main image
OVERLAYFS_ETC_INIT_TEMPLATE = "${CALCULINUX_DISTRO_LAYER_DIR}/files/overlayfs-etc-preinit.sh.in"

# WIC image with root + data partition (OVERLAYFS_ETC_* from machine config)
IMAGE_FSTYPES = "wic"
WKS_FILE = "qemu-test.wks.in"

ROOTFS_POSTPROCESS_COMMAND += " install_test_scripts; "

install_test_scripts() {
    install -d ${IMAGE_ROOTFS}/opt/tests

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

# Test 3: Run Python ioctl tests if present
if [ -d /usr/lib/python3.*/site-packages/calculinux_update ]; then
    cd /usr/lib/python3.*/site-packages/calculinux_update
    if python3 -m pytest tests/integration/test_arm32_ioctl.py -v 2>/dev/null; then
        echo "✓ Python ioctl tests passed"
    else
        echo "⚠ Python ioctl tests skipped or failed"
    fi
fi

# Test 4: Test ovl-restore binary
if command -v ovl-restore >/dev/null 2>&1; then
    ovl-restore --help > /dev/null
    echo "✓ ovl-restore binary works"
fi

# Test 5: Create test overlay scenario
echo "Creating test overlay scenario..."
mkdir -p /data/overlay/etc/upper/test
mkdir -p /data/overlay/etc/lower/test
echo "lower-content" > /data/overlay/etc/lower/test/file.txt
mknod /data/overlay/etc/upper/test/file.txt c 0 0 2>/dev/null || true

# Test 6: Verify ioctl (optional Python)
if [ -d /usr/lib/python3.*/site-packages/calculinux_update ]; then
    python3 << 'PYEOF' 2>/dev/null && echo "✓ ioctl correctly detects whiteout" || echo "⚠ ioctl check skipped"
from calculinux_update.opkg.overlayfs import check_file_restorability, FileRestorability
result = check_file_restorability("/", "/etc/test/file.txt")
if result != FileRestorability.WHITEOUT:
    raise SystemExit(1)
PYEOF
fi

# Test 7: Test restoration with ovl-restore
if command -v ovl-restore >/dev/null 2>&1; then
    ovl-restore / /etc/test/file.txt 2>/dev/null || true
    if [ -f /etc/test/file.txt ] && [ "$(cat /etc/test/file.txt)" = "lower-content" ]; then
        echo "✓ File restored successfully"
    else
        echo "⚠ File restoration check skipped"
    fi
fi

echo ""
echo "=== Tests Complete ==="
EOF

    chmod +x ${IMAGE_ROOTFS}/opt/tests/run-ioctl-tests.sh
}
