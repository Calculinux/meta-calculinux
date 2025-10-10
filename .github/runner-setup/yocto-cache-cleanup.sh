#!/bin/bash
# Yocto Cache Cleanup Script
# Removes old sstate-cache entries to prevent unlimited growth
# Run by systemd timer: yocto-cache-cleanup.timer

set -euo pipefail

# Configuration
CACHE_BASE="/opt/yocto-cache/calculinux"
SSTATE_DIR="${CACHE_BASE}/sstate-cache"
DL_DIR="${CACHE_BASE}/downloads"
MAX_AGE_DAYS=30
MIN_FREE_GB=50

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting Yocto cache cleanup..."

# Check if cache directories exist
if [ ! -d "$CACHE_BASE" ]; then
    log "Cache directory $CACHE_BASE does not exist, nothing to clean"
    exit 0
fi

# Show current cache sizes
if [ -d "$SSTATE_DIR" ]; then
    SSTATE_SIZE=$(du -sh "$SSTATE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    log "Current sstate-cache size: $SSTATE_SIZE"
fi

if [ -d "$DL_DIR" ]; then
    DL_SIZE=$(du -sh "$DL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    log "Current downloads cache size: $DL_SIZE"
fi

# Check available disk space
AVAILABLE_GB=$(df -BG "$CACHE_BASE" | awk 'NR==2 {print $4}' | sed 's/G//')
log "Available disk space: ${AVAILABLE_GB}GB"

# Clean sstate-cache: remove files older than MAX_AGE_DAYS
if [ -d "$SSTATE_DIR" ]; then
    log "Removing sstate-cache entries older than $MAX_AGE_DAYS days..."
    SSTATE_BEFORE=$(find "$SSTATE_DIR" -type f | wc -l)
    
    find "$SSTATE_DIR" -type f -mtime +${MAX_AGE_DAYS} -delete
    find "$SSTATE_DIR" -type d -empty -delete
    
    SSTATE_AFTER=$(find "$SSTATE_DIR" -type f | wc -l)
    SSTATE_REMOVED=$((SSTATE_BEFORE - SSTATE_AFTER))
    log "Removed $SSTATE_REMOVED sstate entries"
    
    SSTATE_SIZE_AFTER=$(du -sh "$SSTATE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    log "New sstate-cache size: $SSTATE_SIZE_AFTER"
fi

# If disk space is critically low, be more aggressive
if [ "$AVAILABLE_GB" -lt "$MIN_FREE_GB" ]; then
    log "WARNING: Low disk space (${AVAILABLE_GB}GB < ${MIN_FREE_GB}GB), performing aggressive cleanup..."
    
    # Remove files older than 14 days
    if [ -d "$SSTATE_DIR" ]; then
        log "Removing sstate-cache entries older than 14 days..."
        find "$SSTATE_DIR" -type f -mtime +14 -delete
        find "$SSTATE_DIR" -type d -empty -delete
    fi
    
    # Clean download cache of old tarballs
    if [ -d "$DL_DIR" ]; then
        log "Removing downloads older than 60 days..."
        find "$DL_DIR" -type f -mtime +60 -delete
        find "$DL_DIR" -type d -empty -delete
    fi
    
    AVAILABLE_GB_AFTER=$(df -BG "$CACHE_BASE" | awk 'NR==2 {print $4}' | sed 's/G//')
    log "Available disk space after aggressive cleanup: ${AVAILABLE_GB_AFTER}GB"
fi

log "Yocto cache cleanup completed successfully"
