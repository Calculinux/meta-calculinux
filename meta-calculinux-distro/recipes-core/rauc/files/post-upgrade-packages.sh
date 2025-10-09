#!/bin/sh
# Run after reboot to new system slot
# This script runs on first boot after RAUC update to reinstall packages

set -e

LOG_TAG="calculinux-post-upgrade"

log_info() {
    echo "$1"
    logger -t "$LOG_TAG" "$1"
}

log_error() {
    echo "ERROR: $1" >&2
    logger -t "$LOG_TAG" -p err "$1"
}

UPGRADE_FLAG="/data/overlay/etc/upper/.calculinux-upgrade-pending"
VERSION_FILE="/data/overlay/etc/upper/calculinux-version"

# Check if upgrade is pending
if [ ! -f "$UPGRADE_FLAG" ]; then
    log_info "No upgrade pending, skipping"
    exit 0
fi

log_info "=== Package Reinstallation After System Upgrade ==="

# Read upgrade metadata
FORCE_REINSTALL=0
if [ -f "$UPGRADE_FLAG" ]; then
    . "$UPGRADE_FLAG"  # Source the flag file for variables
fi

CURRENT_VERSION="__LAYERSERIES_CORENAMES__"

# Check if opkg exists
if ! command -v opkg >/dev/null 2>&1; then
    log_info "opkg not found, skipping"
    rm -f "$UPGRADE_FLAG"
    exit 0
fi

PACKAGE_COUNT=$(opkg list-installed 2>/dev/null | wc -l)
if [ "$PACKAGE_COUNT" -eq 0 ]; then
    log_info "No user packages installed"
    rm -f "$UPGRADE_FLAG"
    exit 0
fi

log_info "Found $PACKAGE_COUNT installed package(s)"

# Major upgrade: force reinstall everything
if [ "$FORCE_REINSTALL" = "1" ]; then
    log_info "Force reinstalling all packages for compatibility..."
    
    # Update opkg feed URLs to match current system version
    OPKG_CONF="/etc/opkg/opkg.conf"
    if [ -f "$OPKG_CONF" ]; then
        log_info "Updating package feed URLs to $CURRENT_VERSION"
        sed -i "s|/ipk/[^/]*/|/ipk/$CURRENT_VERSION/|g" "$OPKG_CONF"
    else
        log_error "opkg.conf not found at $OPKG_CONF"
        rm -f "$UPGRADE_FLAG"
        exit 1
    fi
    
    # Update package lists first
    if ! opkg update; then
        log_error "Failed to update package lists"
        log_error "Check network connectivity and try: calculinux-upgrade-check --upgrade"
        exit 0  # Don't fail the service, just warn
    fi
    
    # Reinstall each package - use process substitution to avoid subshell
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
        log_error "Please run 'calculinux-upgrade-check --upgrade' to retry"
        # Don't remove flag - let user fix manually
    else
        log_info "All packages reinstalled successfully"
        rm -f "$UPGRADE_FLAG"
    fi
    
# Minor upgrade: smart upgrade only
else
    log_info "Minor update detected, running smart upgrade..."
    
    if command -v calculinux-upgrade-check >/dev/null 2>&1; then
        if calculinux-upgrade-check --auto; then
            log_info "Package compatibility check passed"
            rm -f "$UPGRADE_FLAG"
        else
            log_error "Package compatibility issues detected"
            log_error "Please run 'calculinux-upgrade-check' to fix"
        fi
    else
        log_info "calculinux-upgrade-check not found, skipping"
        rm -f "$UPGRADE_FLAG"
    fi
fi

log_info "=== Post-Upgrade Package Reinstallation Complete ==="
exit 0
