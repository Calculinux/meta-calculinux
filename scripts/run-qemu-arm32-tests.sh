#!/bin/bash
# Run ARM32 tests in QEMU for calculinux-update / ovl-restore.
# Usage: ./scripts/run-qemu-arm32-tests.sh [build|test|both]
#
# Uses KAS build dir: KAS_BUILD_DIR if set, else ./build (default for kas build).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${KAS_BUILD_DIR:-${REPO_DIR}/build}"
KAS_YAML="${REPO_DIR}/kas-qemu-arm32-test.yaml"
IMAGE_DIR="${BUILD_DIR}/tmp/deploy/images/qemu-arm32-test"
WIC_IMAGE="${IMAGE_DIR}/calculinux-qemu-test-image-qemu-arm32-test.wic"

ACTION="${1:-both}"

build_image() {
    echo "=== Building QEMU ARM32 Test Image ==="
    cd "$REPO_DIR"
    if [ -x "./kas-container" ]; then
        ./kas-container build "${KAS_YAML}" --build-dir "${BUILD_DIR}"
    else
        kas build "${KAS_YAML}" --build-dir "${BUILD_DIR}"
    fi
    echo "✓ Build complete"
}

run_tests() {
    echo "=== Running Tests in QEMU ARM32 ==="

    if [ ! -f "${WIC_IMAGE}" ]; then
        echo "ERROR: Image not found at ${WIC_IMAGE}"
        echo "Run with 'build' or 'both' first, or set KAS_BUILD_DIR to your build directory."
        exit 1
    fi

    cd "${BUILD_DIR}"
    # Boot QEMU; runqemu expects to be run from build dir
    timeout 120 runqemu qemu-arm32-test nographic \
        qemuparams="-serial mon:stdio" \
        bootparams="init=/bin/bash" || true

    echo "✓ QEMU run finished (manual test: login and run /opt/tests/run-ioctl-tests.sh)"
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
