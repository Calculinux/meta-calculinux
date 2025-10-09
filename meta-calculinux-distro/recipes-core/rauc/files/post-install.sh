#!/bin/sh
# RAUC post-install hook - runs after system update, before reboot
# Prepares for first-boot package installation after successful boot verification

# Source common library
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/rauc-upgrade-common.sh"

LOG_TAG="rauc-post-install"

log_info "=== RAUC Post-Install: Package Compatibility Check ==="

# Get versions
CURRENT_VERSION="__LAYERSERIES_CORENAMES__"  # Replaced during build
OLD_VERSION=$(get_current_version)

log_info "Previous version: $OLD_VERSION"
log_info "Current version: $CURRENT_VERSION"

# Detect if this is a major version upgrade
FORCE_REINSTALL=0
if is_major_version_upgrade "$OLD_VERSION" "$CURRENT_VERSION"; then
    log_info "Major version upgrade detected!"
    FORCE_REINSTALL=1
fi

# Save current version for next upgrade
set_current_version "$CURRENT_VERSION"

# Check if opkg and packages exist
if ! check_opkg_available; then
    log_info "opkg not found, skipping package check"
    exit 0
fi

PACKAGE_COUNT=$(get_installed_package_count)
if [ "$PACKAGE_COUNT" -eq 0 ]; then
    log_info "No user packages installed"
    exit 0
fi

log_info "Found $PACKAGE_COUNT installed package(s)"

# Major upgrade: prepare for first-boot package installation
if [ $FORCE_REINSTALL -eq 1 ]; then
    log_info "Packages will be installed on first boot after successful boot verification"
    
    # Verify we have cached packages
    if has_package_cache; then
        CACHED_COUNT=$(get_cached_package_count)
        log_info "Package cache ready with $CACHED_COUNT package(s)"
    else
        log_warning "No package cache found"
        log_warning "First-boot service will attempt to download packages from network"
    fi
    
    # Update opkg configuration for new version
    OPKG_CONF="/etc/opkg/opkg.conf"
    if [ -f "$OPKG_CONF" ]; then
        log_info "Updating package feed URLs to $CURRENT_VERSION"
        sed -i "s|/ipk/[^/]*/|/ipk/$CURRENT_VERSION/|g" "$OPKG_CONF"
    else
        log_error "opkg.conf not found at $OPKG_CONF"
    fi
    
else
    # Minor upgrade: run smart upgrade immediately
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
