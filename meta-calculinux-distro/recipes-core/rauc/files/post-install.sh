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
    
    # Update opkg feed URLs to match current system version
    OPKG_CONF="/etc/opkg/opkg.conf"
    if [ -f "$OPKG_CONF" ]; then
        log_info "Updating package feed URLs to $CURRENT_VERSION"
        sed -i "s|/ipk/[^/]*/|/ipk/$CURRENT_VERSION/|g" "$OPKG_CONF"
    else
        log_error "opkg.conf not found at $OPKG_CONF"
    fi
    
    # Update package lists first
    opkg update || log_error "Failed to update package lists"
    
    # Reinstall each package
    FAILED=0
    opkg list-installed | awk '{print $1}' | while read pkg; do
        log_info "Reinstalling: $pkg"
        if ! opkg install --force-reinstall "$pkg" 2>&1 | logger -t "$LOG_TAG"; then
            log_error "Failed to reinstall: $pkg"
            FAILED=$((FAILED + 1))
        fi
    done
    
    if [ $FAILED -gt 0 ]; then
        log_error "$FAILED package(s) failed to reinstall"
        log_error "Please review with 'calculinux-upgrade-check' after reboot"
    else
        log_info "All packages reinstalled successfully"
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
