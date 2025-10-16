#!/bin/sh
# RAUC pre-install hook - runs before system update
# Downloads packages for major version upgrades to ensure availability

# Source common library
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/rauc-upgrade-common.sh"

LOG_TAG="rauc-pre-install"

log_info "=== RAUC Pre-Install: Version Check ==="

# Get versions
BUNDLE_VERSION="__LAYERSERIES_CORENAMES__"  # Replaced during build
CURRENT_VERSION=$(get_current_version)

log_info "Current system version: $CURRENT_VERSION"
log_info "Bundle version: $BUNDLE_VERSION"

# Check if this is a major version upgrade
if is_major_version_upgrade "$CURRENT_VERSION" "$BUNDLE_VERSION"; then
    log_warning "========================================================"
    log_warning "  MAJOR VERSION UPGRADE DETECTED"
    log_warning "  $CURRENT_VERSION → $BUNDLE_VERSION"
    log_warning "========================================================"
    log_warning ""
    
    # Check if opkg and packages exist
    if check_opkg_available; then
        PACKAGE_COUNT=$(get_installed_package_count)
        
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
            if ! check_network_connectivity; then
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
                
                wait_with_cancel 10 "Waiting 10 seconds before proceeding..."
            else
                log_info "Pre-downloading packages for new version..."
                log_info ""
                
                # Create package cache
                create_package_cache
                
                # Backup and update opkg config
                OPKG_CONF="/etc/opkg/opkg.conf"
                OPKG_CONF_BACKUP="/tmp/opkg.conf.backup"
                
                if backup_opkg_config "$OPKG_CONF_BACKUP"; then
                    
                    # Update feed URLs to new version
                    log_info "Temporarily updating package feed URLs to $BUNDLE_VERSION"
                    sed -i "s|/ipk/[^/]*/|/ipk/$BUNDLE_VERSION/|g" "$OPKG_CONF"
                    
                    # Update package lists
                    log_info "Updating package lists for $BUNDLE_VERSION..."
                    if opkg update 2>&1 | logger -t "$LOG_TAG"; then
                        log_info "Package lists updated successfully"
                        
                        # Download all currently installed packages for new version
                        log_info "Downloading packages..."
                        DOWNLOAD_FAILED=0
                        DOWNLOAD_COUNT=0
                        
                        opkg list-installed | awk '{print $1}' | while read pkg; do
                            log_info "  Downloading: $pkg"
                            if opkg download "$pkg" -d "$PACKAGE_CACHE_DIR" 2>&1 | logger -t "$LOG_TAG"; then
                                DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
                            else
                                log_error "  Failed to download: $pkg"
                                DOWNLOAD_FAILED=$((DOWNLOAD_FAILED + 1))
                            fi
                        done
                        
                        # Move downloaded packages to cache
                        if ls *.ipk >/dev/null 2>&1; then
                            mv *.ipk "$PACKAGE_CACHE_DIR/" 2>/dev/null || true
                        fi
                        
                        # Count actual files
                        CACHED_COUNT=$(get_cached_package_count)
                        
                        if [ "$CACHED_COUNT" -eq "$PACKAGE_COUNT" ]; then
                            log_info "Successfully pre-downloaded all $CACHED_COUNT package(s)"
                            log_info "Packages cached in: $PACKAGE_CACHE_DIR"
                            
                            # Create version marker for rollback detection
                            echo "$BUNDLE_VERSION" > "$PACKAGE_CACHE_DIR/.version"
                            log_info "Created version marker: $BUNDLE_VERSION"
                        else
                            log_warning "Downloaded $CACHED_COUNT of $PACKAGE_COUNT packages"
                            
                            if [ "$CACHED_COUNT" -eq 0 ]; then
                                log_error "========================================================"
                                log_error "  PACKAGE DOWNLOAD FAILED"
                                log_error "========================================================"
                                log_error ""
                                log_error "Could not download any packages from new repository."
                                log_error ""
                                log_error "Options:"
                                log_error "  1. Cancel this update (Ctrl+C now)"
                                log_error "  2. Check network connectivity and retry"
                                log_error "  3. Continue anyway (post-install will attempt download)"
                                log_error ""
                                wait_with_cancel 10 "Waiting 10 seconds before proceeding..."
                            else
                                log_warning "Some packages failed to download"
                                log_warning "Post-install will attempt to download missing packages"
                            fi
                        fi
                    else
                        log_error "Failed to update package lists for new version"
                        log_error "Post-install will attempt to download packages"
                    fi
                    
                    # Restore original config
                    restore_opkg_config "$OPKG_CONF_BACKUP"
                    
                    # Restore package lists for current version
                    opkg update 2>&1 | logger -t "$LOG_TAG" || true
                else
                    log_error "opkg.conf not found, cannot pre-download packages"
                fi
                
                log_info ""
                log_info "Proceeding with update. Package reinstallation will"
                log_info "occur automatically after reboot using cached packages."
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
    
else
    log_info "Same version or first installation"
    log_info "Package reinstallation not required."
fi

log_info "=== RAUC Pre-Install Check Complete ==="
exit 0
