#!/bin/sh
# RAUC post-install system handler wrapper
# This calls cup-hook for each target rootfs slot after installation completes
# The status.image file is obtained from the bundle extras, not from the slot itself

set -e

echo "RAUC post-install handler starting"
echo "RAUC_BUNDLE_MOUNT_POINT=${RAUC_BUNDLE_MOUNT_POINT}"
echo "RAUC_TARGET_SLOTS=${RAUC_TARGET_SLOTS}"

# Extract bundle extras if present (tarball contains extras/ e.g. extras/opkg/status.image)
EXTRAS_TARBALL="${RAUC_BUNDLE_MOUNT_POINT}/bundle-extras.tar.gz"
if [ -f "${EXTRAS_TARBALL}" ]; then
    echo "Extracting bundle extras..."
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
