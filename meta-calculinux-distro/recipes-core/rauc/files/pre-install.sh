#!/bin/sh
# RAUC pre-install hook - runs before system update
# Warns user about major version upgrades requiring package reinstallation

# Log to journal and stdout
LOG_TAG="rauc-pre-install"

log_info() {
    echo "$1"
    logger -t "$LOG_TAG" "$1"
}

log_warning() {
    echo "WARNING: $1" >&2
    logger -t "$LOG_TAG" -p warning "$1"
}

log_error() {
    echo "ERROR: $1" >&2
    logger -t "$LOG_TAG" -p err "$1"
}

log_info "=== RAUC Pre-Install: Version Check ==="

# Version tracking file (persistent across updates)
VERSION_FILE="/data/overlay/etc/upper/calculinux-version"
BUNDLE_VERSION="__LAYERSERIES_CORENAMES__"  # Replaced during build

# Get current version
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    log_info "Current system version: $CURRENT_VERSION"
else
    CURRENT_VERSION="unknown"
    log_info "Current version unknown (first install or missing version file)"
fi

log_info "Bundle version: $BUNDLE_VERSION"

# Check if this is a major version upgrade
if [ "$CURRENT_VERSION" != "$BUNDLE_VERSION" ] && [ "$CURRENT_VERSION" != "unknown" ]; then
    log_warning "========================================================"
    log_warning "  MAJOR VERSION UPGRADE DETECTED"
    log_warning "  $CURRENT_VERSION → $BUNDLE_VERSION"
    log_warning "========================================================"
    log_warning ""
    
    # Check if opkg and packages exist
    if command -v opkg >/dev/null 2>&1; then
        PACKAGE_COUNT=$(opkg list-installed 2>/dev/null | wc -l)
        
        if [ "$PACKAGE_COUNT" -gt 0 ]; then
            log_warning "User-installed packages detected: $PACKAGE_COUNT package(s)"
            log_warning ""
            log_warning "After this update, ALL user packages will be automatically"
            log_warning "reinstalled from the new package repository to ensure"
            log_warning "compatibility with the updated system libraries."
            log_warning ""
            log_warning "IMPORTANT: Ensure network connectivity for package download!"
            log_warning ""
            log_warning "Package list:"
            opkg list-installed | awk '{printf "  - %s (%s)\n", $1, $3}' | logger -t "$LOG_TAG"
            opkg list-installed | awk '{printf "  - %s (%s)\n", $1, $3}'
            log_warning ""
            
            # Estimate download size (rough estimate: 1MB average per package)
            ESTIMATED_MB=$((PACKAGE_COUNT * 1))
            log_warning "Estimated download size: ~${ESTIMATED_MB} MB"
            log_warning ""
            
            # Check for network connectivity
            if ! ping -c 1 -W 2 opkg.calculinux.org >/dev/null 2>&1; then
                log_error "========================================================"
                log_error "  NETWORK CONNECTIVITY WARNING"
                log_error "========================================================"
                log_error ""
                log_error "Cannot reach package repository (opkg.calculinux.org)"
                log_error ""
                log_error "Options:"
                log_error "  1. Cancel this update (Ctrl+C now)"
                log_error "  2. Connect to network and retry"
                log_error "  3. Continue anyway (packages may fail to reinstall)"
                log_error ""
                log_error "If you continue without network access, user packages"
                log_error "may not work until you run 'calculinux-upgrade-check'"
                log_error "with network connectivity."
                log_error ""
                
                # Give user time to read and potentially cancel
                log_error "Waiting 10 seconds before proceeding..."
                log_error "Press Ctrl+C to cancel the update"
                sleep 10
            else
                log_info "Network connectivity: OK"
                log_info ""
                log_info "Proceeding with update. Package reinstallation will"
                log_info "occur automatically after reboot."
                log_info ""
                # Brief pause for user to read
                sleep 3
            fi
        else
            log_info "No user packages installed, proceeding with update."
        fi
    else
        log_info "Package manager not found, proceeding with update."
    fi
    
    log_warning "========================================================"
    
elif [ "$CURRENT_VERSION" = "$BUNDLE_VERSION" ]; then
    log_info "Minor/patch update within same version ($BUNDLE_VERSION)"
    log_info "Package reinstallation not required."
    
else
    log_info "First installation or version upgrade from unknown version"
    log_info "Proceeding with installation."
fi

log_info "=== RAUC Pre-Install Check Complete ==="
exit 0
