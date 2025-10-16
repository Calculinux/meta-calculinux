#!/bin/sh
# First-boot package installation after successful RAUC upgrade
# Runs AFTER RAUC marks boot as successful, ensuring A/B safety

# Source common library
SCRIPT_DIR="$(dirname "$0")"
COMMON_LIB="/usr/lib/rauc/rauc-upgrade-common.sh"

if [ -f "$COMMON_LIB" ]; then
    . "$COMMON_LIB"
else
    # Fallback minimal logging if library not available
    log_info() { echo "$1"; logger -t "rauc-firstboot" "$1"; }
    log_error() { echo "ERROR: $1" >&2; logger -t "rauc-firstboot" -p err "$1"; }
fi

LOG_TAG="rauc-firstboot"

log_info "=== RAUC First-Boot: Package Installation ==="

# Check if there are cached packages to install
if ! has_package_cache; then
    log_info "No cached packages found, nothing to do"
    exit 0
fi

CACHED_COUNT=$(get_cached_package_count)
log_info "Found $CACHED_COUNT cached package(s) from upgrade"

# Check if cache is for current version (rollback detection)
VERSION_MARKER="$PACKAGE_CACHE_DIR/.version"
if [ -f "$VERSION_MARKER" ]; then
    CACHE_VERSION=$(cat "$VERSION_MARKER")
    CURRENT_VERSION=$(get_current_version)
    
    if [ "$CACHE_VERSION" != "$CURRENT_VERSION" ]; then
        log_warning "Cache version mismatch - rollback detected"
        log_warning "  Cache: $CACHE_VERSION, System: $CURRENT_VERSION"
        log_warning "Cleaning up incompatible package cache"
        cleanup_package_cache
        exit 0
    fi
    log_info "Cache version matches system: $CURRENT_VERSION"
else
    log_warning "No version marker in cache"
fi

# Check if opkg is available
if ! check_opkg_available; then
    log_error "opkg not found, cannot install packages"
    exit 1
fi

# Get list of currently installed packages
PACKAGE_COUNT=$(get_installed_package_count)
if [ "$PACKAGE_COUNT" -eq 0 ]; then
    log_info "No packages to reinstall"
    cleanup_package_cache
    exit 0
fi

log_info "Reinstalling $PACKAGE_COUNT package(s) for new system version"

# Update package lists
if opkg update 2>&1 | logger -t "$LOG_TAG"; then
    log_info "Package lists updated"
else
    log_error "Failed to update package lists"
fi

# Reinstall each package from cache
FAILED=0
INSTALLED=0

while read pkg; do
    # Try to find package in cache
    CACHED_PKG=$(find_cached_package "$pkg")
    
    if [ -n "$CACHED_PKG" ]; then
        log_info "Installing from cache: $pkg"
        if opkg install --force-reinstall "$CACHED_PKG" 2>&1 | logger -t "$LOG_TAG"; then
            INSTALLED=$((INSTALLED + 1))
        else
            log_error "Failed to install from cache: $pkg, trying network"
            # Fallback to network download
            if opkg install --force-reinstall "$pkg" 2>&1 | logger -t "$LOG_TAG"; then
                INSTALLED=$((INSTALLED + 1))
            else
                log_error "Failed to install: $pkg"
                FAILED=$((FAILED + 1))
            fi
        fi
    else
        log_info "Installing (not in cache): $pkg"
        if opkg install --force-reinstall "$pkg" 2>&1 | logger -t "$LOG_TAG"; then
            INSTALLED=$((INSTALLED + 1))
        else
            log_error "Failed to install: $pkg"
            FAILED=$((FAILED + 1))
        fi
    fi
done < <(get_installed_packages)

# Report results
if [ $FAILED -gt 0 ]; then
    log_error "Package installation completed with $FAILED failure(s)"
    log_error "Installed: $INSTALLED, Failed: $FAILED"
    log_error "Please review with 'calculinux-upgrade-check'"
    
    # Don't clean up cache if there were failures
    # (allows manual recovery)
    exit 1
else
    log_info "All $INSTALLED package(s) installed successfully"
    
    # Clean up cache on success
    cleanup_package_cache
    log_info "Package cache cleaned up"
fi

log_info "=== RAUC First-Boot Package Installation Complete ==="
exit 0
