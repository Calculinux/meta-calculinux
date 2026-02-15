#!/bin/bash
# Load device tree overlays listed in a config file using ConfigFS.
#
# Usage: load-dt-overlays.sh [config-file]
# Default config file: /etc/device-tree-overlays.conf
#
# Config format (one overlay per line):
#   - Blank lines and lines starting with # are ignored
#   - Lines may be:
#       * an overlay name (with or without .dtbo), resolved first in /etc/devicetree/, then /boot/devicetree/
#       * an absolute path to a .dtbo file
#
# Example:
#   ds3231-rtc
#   /data/overlays/custom-sensor.dtbo

set -e

CONFIG_FILE="${1:-/etc/device-tree-overlays.conf}"

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Exit silently if config file doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# Wait for ConfigFS to be mounted (should already be mounted by kernel)
CONFIGFS_TIMEOUT=10
ELAPSED=0

while [[ ! -d /sys/kernel/config/device-tree/overlays ]]; do
    if (( ELAPSED >= CONFIGFS_TIMEOUT )); then
        echo "ERROR: ConfigFS device-tree interface not available after ${CONFIGFS_TIMEOUT}s" >&2
        exit 1
    fi
    sleep 1
    ((ELAPSED++))
done

CONFIGFS_DIR="/sys/kernel/config/device-tree/overlays"
LOADED=0
FAILED=0

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%%#*}"
    line="$(trim "$line")"

    [[ -z "$line" ]] && continue

    if [[ "$line" == /* ]]; then
        overlay_file="$line"
    elif [[ "$line" == */* ]]; then
        overlay_file="$line"
    else
        if [[ "$line" != *.dtbo ]]; then
            line="${line}.dtbo"
        fi
        # Check user directory first, then system directory
        if [[ -f "/etc/devicetree/${line}" ]]; then
            overlay_file="/etc/devicetree/${line}"
        else
            overlay_file="/boot/devicetree/${line}"
        fi
    fi

    if [[ ! -f "$overlay_file" ]]; then
        echo "ERROR: Overlay not found: $overlay_file" >&2
        ((FAILED++))
        continue
    fi

    overlay_name=$(basename "$overlay_file" .dtbo)
    overlay_path="$CONFIGFS_DIR/$overlay_name"

    echo "Loading device tree overlay: $overlay_name"

    # Create overlay directory
    if ! mkdir -p "$overlay_path" 2>/dev/null; then
        # Directory might already exist, that's okay
        if [[ -d "$overlay_path" ]]; then
            # Check if already loaded
            if [[ -e "$overlay_path/dtbo" ]]; then
                echo "  -> Already loaded, skipping"
                ((LOADED++))
                continue
            fi
        else
            echo "  -> ERROR: Failed to create directory for $overlay_name" >&2
            ((FAILED++))
            continue
        fi
    fi

    # Load the overlay blob (kernel applies immediately on write; status is read-only)
    if cat "$overlay_file" > "$overlay_path/dtbo" 2>/dev/null; then
        if [[ "$(cat "$overlay_path/status" 2>/dev/null)" == "applied" ]]; then
            echo "  -> Loaded successfully"
            ((LOADED++))
        else
            echo "  -> ERROR: Overlay blob written but status is not 'applied' (check dmesg)" >&2
            ((FAILED++))
            rmdir "$overlay_path" 2>/dev/null || true
        fi
    else
        echo "  -> ERROR: Failed to load overlay blob" >&2
        ((FAILED++))
        rmdir "$overlay_path" 2>/dev/null || true
    fi
done < "$CONFIG_FILE"

echo "Overlay loading complete: $LOADED loaded, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
