#!/bin/sh
# RAUC post-install system handler wrapper
# This calls cup-hook for each target rootfs slot after installation completes

set -e

# Iterate over all target slots that were updated
for i in ${RAUC_TARGET_SLOTS}; do
    eval SLOT_NAME=\$RAUC_SLOT_NAME_${i}
    eval SLOT_CLASS=\$RAUC_SLOT_CLASS_${i}
    
    # Only process rootfs slots
    if [ "${SLOT_CLASS}" = "rootfs" ]; then
        echo "Running post-install hook for slot ${SLOT_NAME}"
        
        # Export slot-specific environment variables that cup-hook expects
        export RAUC_SLOT_CLASS="${SLOT_CLASS}"
        eval export RAUC_SLOT_DEVICE=\$RAUC_SLOT_DEVICE_${i}
        eval export RAUC_SLOT_TYPE=\$RAUC_SLOT_TYPE_${i}
        eval export RAUC_SLOT_BOOTNAME=\$RAUC_SLOT_BOOTNAME_${i}
        
        # The slot should be mounted by RAUC at this point
        # Mount point is typically ${RAUC_MOUNT_PREFIX}/${SLOT_NAME}
        export RAUC_SLOT_MOUNT_POINT="${RAUC_MOUNT_PREFIX}/${SLOT_NAME}"
        
        # Call cup-hook with slot-post-install hook type
        /usr/bin/cup-hook slot-post-install "${SLOT_NAME}"
    fi
done

exit 0
