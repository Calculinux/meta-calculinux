#!/bin/sh
# RAUC post-install hook - runs after system update
# Automatically checks and upgrades user packages
# On major version upgrades, force reinstall all packages

# Log to journal
LOG_TAG="rauc-post-install"

log_info() {
    echo "$1"
    logger -t "$LOG_TAG" "$1"
}

log_error() {
    echo "ERROR: $1" >&2
    logger -t "$LOG_TAG" -p err "$1"
}

log_info "=== RAUC Post-Install: Package Compatibility Check ==="

# Version tracking file (persistent across updates)
VERSION_FILE="/data/overlay/etc/upper/calculinux-version"
CURRENT_VERSION="__LAYERSERIES_CORENAMES__"  # Replaced during build

# Detect if this is a major version upgrade
FORCE_REINSTALL=0
if [ -f "$VERSION_FILE" ]; then
    OLD_VERSION=$(cat "$VERSION_FILE")
    log_info "Previous version: $OLD_VERSION"
    log_info "Current version: $CURRENT_VERSION"
    
    if [ "$OLD_VERSION" != "$CURRENT_VERSION" ]; then
        log_info "Major version upgrade detected!"
        FORCE_REINSTALL=1
    fi
else
    log_info "First boot or version file missing"
fi

# Save current version for next upgrade
mkdir -p "$(dirname "$VERSION_FILE")"
echo "$CURRENT_VERSION" > "$VERSION_FILE"

# Check if opkg and packages exist
if ! command -v opkg >/dev/null 2>&1; then
    log_info "opkg not found, skipping package check"
    exit 0
fi

PACKAGE_COUNT=$(opkg list-installed 2>/dev/null | wc -l)
if [ "$PACKAGE_COUNT" -eq 0 ]; then
    log_info "No user packages installed"
    exit 0
fi

log_info "Found $PACKAGE_COUNT installed package(s)"

# Major upgrade: force reinstall everything
if [ $FORCE_REINSTALL -eq 1 ]; then
    log_info "Force reinstalling all packages for compatibility..."
    
    # Determine which slot was just updated (the target slot to boot next)
    # RAUC provides RAUC_TARGET_SLOTS as an iterator and slot info via indexed variables
    TARGET_SLOT_DEVICE=""
    TARGET_SLOT_NAME=""
    
    if [ -n "$RAUC_TARGET_SLOTS" ]; then
        # Find the first bootable target slot (there should typically be one for rootfs)
        for slot_idx in $RAUC_TARGET_SLOTS; do
            eval SLOT_NAME=\$RAUC_SLOT_NAME_${slot_idx}
            eval SLOT_DEVICE=\$RAUC_SLOT_DEVICE_${slot_idx}
            eval SLOT_BOOTNAME=\$RAUC_SLOT_BOOTNAME_${slot_idx}
            eval SLOT_CLASS=\$RAUC_SLOT_CLASS_${slot_idx}
            
            # We want the rootfs slot that was just updated
            if [ "$SLOT_CLASS" = "rootfs" ] && [ -n "$SLOT_BOOTNAME" ]; then
                TARGET_SLOT_NAME="$SLOT_NAME"
                TARGET_SLOT_DEVICE="$SLOT_DEVICE"
                log_info "Found target slot: $TARGET_SLOT_NAME ($TARGET_SLOT_DEVICE)"
                break
            fi
        done
    fi
    
    if [ -z "$TARGET_SLOT_DEVICE" ]; then
        log_error "Could not determine target slot from RAUC environment"
        log_error "Available RAUC_TARGET_SLOTS: $RAUC_TARGET_SLOTS"
        log_error "Will attempt package reinstall in current environment (fallback)"
    fi
    
    # Update opkg feed URLs to match current system version
    OPKG_CONF="/etc/opkg/opkg.conf"
    if [ -f "$OPKG_CONF" ]; then
        log_info "Updating package feed URLs to $CURRENT_VERSION"
        sed -i "s|/ipk/[^/]*/|/ipk/$CURRENT_VERSION/|g" "$OPKG_CONF"
    else
        log_error "opkg.conf not found at $OPKG_CONF"
        exit 1
    fi
    
    # If we have a target slot device, create chroot environment with new rootfs
    CHROOT_SUCCESS=0
    if [ -n "$TARGET_SLOT_DEVICE" ]; then
        log_info "Setting up chroot environment with new system..."
        log_info "Target device: $TARGET_SLOT_DEVICE"
        
        CHROOT_DIR="/tmp/upgrade-chroot"
        SLOT_MOUNT="/tmp/new-slot"
        CHROOT_FAILED=0
        
        # Verify target device exists and is a block device
        if [ ! -b "$TARGET_SLOT_DEVICE" ]; then
            log_error "Target device $TARGET_SLOT_DEVICE is not a block device"
            CHROOT_FAILED=1
        fi
        
        # Mount the new slot
        if [ $CHROOT_FAILED -eq 0 ]; then
            mkdir -p "$SLOT_MOUNT"
            if mount -o ro "$TARGET_SLOT_DEVICE" "$SLOT_MOUNT" 2>&1 | logger -t "$LOG_TAG"; then
                log_info "Mounted new slot at $SLOT_MOUNT"
                
                # Create chroot directory structure
                mkdir -p "$CHROOT_DIR"
                
                # Verify data partition is mounted
                DATA_MOUNT="{OVERLAYFS_ETC_MOUNT_POINT}"
                if [ ! -d "$DATA_MOUNT" ]; then
                    log_error "Data partition not mounted at $DATA_MOUNT"
                    CHROOT_FAILED=1
                fi
            else
                log_error "Failed to mount new slot $TARGET_SLOT_DEVICE"
                CHROOT_FAILED=1
            fi
        fi
        
        # Mount overlays if previous steps succeeded
        if [ $CHROOT_FAILED -eq 0 ]; then
            log_info "Mounting overlays in chroot..."
            for overlay in /etc /root /home /var /usr/local /opt; do
                OVERLAY_BASE="$DATA_MOUNT/overlay/$overlay"
                CHROOT_TARGET="$CHROOT_DIR$overlay"
                
                mkdir -p "$CHROOT_TARGET"
                mkdir -p "$OVERLAY_BASE/upper"
                mkdir -p "$OVERLAY_BASE/work"
                
                # Create overlay with new slot as lower, existing uppers
                if ! mount -t overlay overlay \
                    -o lowerdir="$SLOT_MOUNT$overlay" \
                    -o upperdir="$OVERLAY_BASE/upper" \
                    -o workdir="$OVERLAY_BASE/work" \
                    "$CHROOT_TARGET" 2>&1 | logger -t "$LOG_TAG"; then
                    log_error "Failed to mount overlay for $overlay"
                    CHROOT_FAILED=1
                    break
                fi
            done
        fi
        
        # Bind mount essential system directories if previous steps succeeded
        if [ $CHROOT_FAILED -eq 0 ]; then
            log_info "Mounting system directories in chroot..."
            mkdir -p "$CHROOT_DIR"/{proc,sys,dev,tmp,run}
            
            mount -t proc proc "$CHROOT_DIR/proc" 2>&1 | logger -t "$LOG_TAG" || CHROOT_FAILED=1
            mount -t sysfs sys "$CHROOT_DIR/sys" 2>&1 | logger -t "$LOG_TAG" || CHROOT_FAILED=1
            mount -o bind /dev "$CHROOT_DIR/dev" 2>&1 | logger -t "$LOG_TAG" || CHROOT_FAILED=1
            mount -o bind /tmp "$CHROOT_DIR/tmp" 2>&1 | logger -t "$LOG_TAG" || CHROOT_FAILED=1
            mount -o bind /run "$CHROOT_DIR/run" 2>&1 | logger -t "$LOG_TAG" || CHROOT_FAILED=1
            
            if [ $CHROOT_FAILED -eq 0 ]; then
                log_info "Chroot environment ready"
            else
                log_error "Failed to set up system directories in chroot"
            fi
        fi
        
        # Perform package reinstallation in chroot if setup succeeded
        if [ $CHROOT_FAILED -eq 0 ]; then
            # Update package lists in chroot
            log_info "Updating package lists in new environment..."
            if chroot "$CHROOT_DIR" /usr/bin/opkg update 2>&1 | logger -t "$LOG_TAG"; then
                log_info "Package lists updated successfully"
                
                # Reinstall each package in the chroot
                log_info "Reinstalling packages in new environment..."
                FAILED=0
                while read pkg; do
                    log_info "Reinstalling: $pkg"
                    if ! chroot "$CHROOT_DIR" /usr/bin/opkg install --force-reinstall "$pkg" 2>&1 | logger -t "$LOG_TAG"; then
                        log_error "Failed to reinstall: $pkg"
                        FAILED=$((FAILED + 1))
                    fi
                done < <(chroot "$CHROOT_DIR" /usr/bin/opkg list-installed | awk '{print $1}')
                
                if [ $FAILED -gt 0 ]; then
                    log_error "$FAILED package(s) failed to reinstall"
                    log_error "Please review with 'calculinux-upgrade-check' after reboot"
                else
                    log_info "All packages reinstalled successfully in new environment"
                    CHROOT_SUCCESS=1
                fi
            else
                log_error "Failed to update package lists in chroot"
            fi
        fi
        
        # Cleanup chroot
        log_info "Cleaning up chroot environment..."
        umount "$CHROOT_DIR/proc" 2>/dev/null || true
        umount "$CHROOT_DIR/sys" 2>/dev/null || true
        umount "$CHROOT_DIR/dev" 2>/dev/null || true
        umount "$CHROOT_DIR/tmp" 2>/dev/null || true
        umount "$CHROOT_DIR/run" 2>/dev/null || true
        
        for overlay in /etc /root /home /var /usr/local /opt; do
            umount "$CHROOT_DIR$overlay" 2>/dev/null || true
        done
        
        umount "$SLOT_MOUNT" 2>/dev/null || true
        rm -rf "$CHROOT_DIR" "$SLOT_MOUNT"
    fi
    
    # Fallback: reinstall in current environment if chroot setup failed or wasn't attempted
    if [ $CHROOT_SUCCESS -eq 0 ]; then
        log_info "Reinstalling packages in current environment (fallback)..."
        
        # Update package lists first
        if opkg update 2>&1 | logger -t "$LOG_TAG"; then
            log_info "Package lists updated"
        else
            log_error "Failed to update package lists"
        fi
        
        # Reinstall each package
        FAILED=0
        while read pkg; do
            log_info "Reinstalling: $pkg"
            if ! opkg install --force-reinstall "$pkg" 2>&1 | logger -t "$LOG_TAG"; then
                log_error "Failed to reinstall: $pkg"
                FAILED=$((FAILED + 1))
            fi
        done < <(opkg list-installed | awk '{print $1}')

        if [ $FAILED -gt 0 ]; then
            log_error "$FAILED package(s) failed to reinstall"
            log_error "Please review with 'calculinux-upgrade-check' after reboot"
        else
            log_info "All packages reinstalled successfully"
        fi
    fi
    
# Minor upgrade: smart upgrade only
else
    log_info "Minor update detected, running smart upgrade..."
    
    if command -v calculinux-upgrade-check >/dev/null 2>&1; then
        if calculinux-upgrade-check --auto; then
            log_info "Package compatibility check passed"
        else
            log_error "Package compatibility issues detected"
            log_error "Please run 'calculinux-upgrade-check' after reboot"
        fi
    else
        log_info "calculinux-upgrade-check not found, skipping"
    fi
fi

log_info "=== RAUC Post-Install Complete ==="
exit 0
