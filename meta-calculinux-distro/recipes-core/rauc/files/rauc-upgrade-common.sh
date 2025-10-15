#!/bin/sh
# Common library for RAUC upgrade hooks
# Shared functions for pre-install and post-install scripts

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Set LOG_TAG in calling script before sourcing this file
: "${LOG_TAG:=rauc-upgrade}"

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

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

# Version tracking file (persistent across updates on /data partition)
VERSION_FILE="/data/overlay/etc/upper/calculinux-version"

# Get current system version from version file
# Returns: version string, or "unknown" if file doesn't exist
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

# Set/update system version in version file
# Args: $1 = version string
set_current_version() {
    local version="$1"
    mkdir -p "$(dirname "$VERSION_FILE")"
    echo "$version" > "$VERSION_FILE"
}

# Check if this is a major version upgrade
# Args: $1 = old version, $2 = new version
# Returns: 0 if major upgrade, 1 if not
is_major_version_upgrade() {
    local old_version="$1"
    local new_version="$2"
    
    # Not an upgrade if versions match
    if [ "$old_version" = "$new_version" ]; then
        return 1
    fi
    
    # Not an upgrade if old version is unknown (first install)
    if [ "$old_version" = "unknown" ]; then
        return 1
    fi
    
    # Different versions = major upgrade
    return 0
}

# ============================================================================
# NETWORK CONNECTIVITY
# ============================================================================

# Check if network is available
# Returns: 0 if network OK, 1 if not
check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    # Try wget first (more reliable for repository access)
    if wget --spider --timeout=5 --tries=2 http://www.google.com >/dev/null 2>&1; then
        log_info "Network connectivity OK (wget)"
        return 0
    fi
    
    # Fall back to ping
    if ping -c 2 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_info "Network connectivity OK (ping)"
        return 0
    fi
    
    log_warning "No network connectivity detected"
    return 1
}

# ============================================================================
# OPKG PACKAGE MANAGEMENT
# ============================================================================

# Check if opkg is available
# Returns: 0 if available, 1 if not
check_opkg_available() {
    if ! command -v opkg >/dev/null 2>&1; then
        log_info "opkg not found"
        return 1
    fi
    return 0
}

# Get count of installed packages
# Returns: number of installed packages
get_installed_package_count() {
    if ! check_opkg_available; then
        echo "0"
        return
    fi
    
    opkg list-installed 2>/dev/null | wc -l
}

# Get list of installed packages (one per line)
# Returns: package names
get_installed_packages() {
    if ! check_opkg_available; then
        return
    fi
    
    opkg list-installed 2>/dev/null | awk '{print $1}'
}

# Estimate total download size for packages
# Returns: size in bytes
estimate_download_size() {
    if ! check_opkg_available; then
        echo "0"
        return
    fi
    
    # This is approximate - opkg doesn't provide exact download size
    # We use the installed size as a rough estimate
    opkg list-installed 2>/dev/null | \
        awk '{if ($3 ~ /^[0-9]+$/) sum += $3} END {print sum + 0}'
}

# Format bytes into human-readable size
# Args: $1 = size in bytes
# Returns: formatted string (e.g., "1.5 MB")
format_bytes() {
    local bytes="$1"
    
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024)) KB"
    else
        echo "$((bytes / 1048576)) MB"
    fi
}

# ============================================================================
# PACKAGE CACHE MANAGEMENT
# ============================================================================

# Package cache directory for pre-downloaded packages
PACKAGE_CACHE_DIR="/data/overlay/var/cache/opkg-upgrade"

# Create package cache directory
create_package_cache() {
    mkdir -p "$PACKAGE_CACHE_DIR"
    log_info "Created package cache: $PACKAGE_CACHE_DIR"
}

# Check if package cache exists and has packages
# Returns: 0 if cache exists with packages, 1 if not
has_package_cache() {
    if [ ! -d "$PACKAGE_CACHE_DIR" ]; then
        return 1
    fi
    
    local cached_count
    cached_count=$(ls -1 "$PACKAGE_CACHE_DIR"/*.ipk 2>/dev/null | wc -l)
    
    if [ "$cached_count" -gt 0 ]; then
        log_info "Found $cached_count cached package(s)"
        return 0
    fi
    
    return 1
}

# Get count of cached packages
# Returns: number of cached .ipk files
get_cached_package_count() {
    if [ ! -d "$PACKAGE_CACHE_DIR" ]; then
        echo "0"
        return
    fi
    
    ls -1 "$PACKAGE_CACHE_DIR"/*.ipk 2>/dev/null | wc -l
}

# Find cached package file by name
# Args: $1 = package name (without version/arch)
# Returns: full path to .ipk file, or empty if not found
find_cached_package() {
    local package_name="$1"
    
    if [ ! -d "$PACKAGE_CACHE_DIR" ]; then
        return
    fi
    
    # Look for package file matching pattern: packagename_*.ipk
    find "$PACKAGE_CACHE_DIR" -name "${package_name}_*.ipk" -print -quit
}

# Clean up package cache
cleanup_package_cache() {
    if [ -d "$PACKAGE_CACHE_DIR" ]; then
        log_info "Cleaning up package cache..."
        rm -rf "$PACKAGE_CACHE_DIR"
    fi
}

# ============================================================================
# RAUC SLOT DETECTION
# ============================================================================

# Find target RAUC slot device
# Uses RAUC_TARGET_SLOTS and RAUC_SLOT_DEVICE_* environment variables
# Returns: device path (e.g., /dev/mmcblk1p2) or empty if not found
find_target_slot_device() {
    # RAUC_TARGET_SLOTS contains indices like "0" or "0 1"
    # For single-slot updates, this is typically one index
    for slot_idx in $RAUC_TARGET_SLOTS; do
        # Construct variable name: RAUC_SLOT_DEVICE_0, RAUC_SLOT_DEVICE_1, etc.
        eval "slot_device=\$RAUC_SLOT_DEVICE_${slot_idx}"
        
        if [ -n "$slot_device" ] && [ -b "$slot_device" ]; then
            echo "$slot_device"
            return 0
        fi
    done
    
    return 1
}

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

# Backup opkg configuration
# Args: $1 = backup file path
backup_opkg_config() {
    local backup_file="$1"
    
    if [ -f /etc/opkg/opkg.conf ]; then
        cp /etc/opkg/opkg.conf "$backup_file"
        log_info "Backed up opkg.conf to $backup_file"
        return 0
    fi
    
    log_error "Failed to backup opkg.conf"
    return 1
}

# Restore opkg configuration
# Args: $1 = backup file path
restore_opkg_config() {
    local backup_file="$1"
    
    if [ -f "$backup_file" ]; then
        cp "$backup_file" /etc/opkg/opkg.conf
        log_info "Restored opkg.conf from $backup_file"
        rm -f "$backup_file"
        return 0
    fi
    
    log_error "Failed to restore opkg.conf"
    return 1
}

# ============================================================================
# USER INTERACTION
# ============================================================================

# Wait for user with countdown and cancellation option
# Args: $1 = seconds to wait, $2 = message
wait_with_cancel() {
    local wait_seconds="$1"
    local message="$2"
    
    log_warning "$message"
    log_warning "Waiting $wait_seconds seconds..."
    log_warning "Press Ctrl+C to cancel the update"
    
    local i="$wait_seconds"
    while [ "$i" -gt 0 ]; do
        printf "\r  %2d seconds remaining... " "$i"
        sleep 1
        i=$((i - 1))
    done
    printf "\n"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if running in chroot
# Returns: 0 if in chroot, 1 if not
is_chroot() {
    # Simple check: if /proc/1/root is not equal to /
    if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root 2>/dev/null)" ]; then
        return 0
    fi
    return 1
}

# Ensure directory exists
# Args: $1 = directory path
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
    fi
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# This function should be called by scripts that source this library
# to verify the environment is suitable
check_environment() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Must run as root"
        return 1
    fi
    
    # Check if VERSION_FILE parent directory is writable
    if [ ! -w "$(dirname "$VERSION_FILE")" ] && [ ! -d "$(dirname "$VERSION_FILE")" ]; then
        log_warning "Version file directory not writable: $(dirname "$VERSION_FILE")"
    fi
    
    return 0
}
