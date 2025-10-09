#!/bin/sh
# RAUC post-install hook - runs after system update (before reboot)
# Sets flag for package reinstallation on first boot

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
UPGRADE_FLAG="/data/overlay/etc/upper/.calculinux-upgrade-pending"
CURRENT_VERSION="__LAYERSERIES_CORENAMES__"  # Replaced during build

# Ensure directory exists
mkdir -p "$(dirname "$VERSION_FILE")"

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

# Create flag file for post-upgrade service
cat > "$UPGRADE_FLAG" <<EOF
# Calculinux upgrade pending flag
# This file is processed by calculinux-post-upgrade.service on next boot
OLD_VERSION="$OLD_VERSION"
CURRENT_VERSION="$CURRENT_VERSION"
FORCE_REINSTALL=$FORCE_REINSTALL
PACKAGE_COUNT=$PACKAGE_COUNT
EOF

if [ $FORCE_REINSTALL -eq 1 ]; then
    log_info "Major upgrade: Packages will be force-reinstalled on next boot"
else
    log_info "Minor upgrade: Packages will be checked/upgraded on next boot"
fi

log_info "Package reinstallation will occur automatically after reboot"
log_info "=== RAUC Post-Install Complete ==="
exit 0
