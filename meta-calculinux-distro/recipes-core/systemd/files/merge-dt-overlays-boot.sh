#!/bin/bash
# Merge device tree overlays (from /etc/device-tree-overlays.conf and
# /etc/devicetree/) into the base DTB from a given zboot.img, then repack
# the FIT and write to OVERLAY_DATA so U-Boot can load it at next boot.
#
# When SLOT is set (A or B), output is zboot_merged_<slot>.img so each root
# slot has its own merged FIT; U-Boot loads the one matching the chosen slot.
# When SLOT is unset (legacy), output is zboot_merged.img (single file).
#
# Config: /etc/device-tree-overlays.conf (same format as load-dt-overlays.sh).
# Overlays: /etc/devicetree/*.dtbo and /boot/devicetree/*.dtbo; only those
# listed in the config are applied.
#
# Usage: merge-dt-overlays-boot.sh [CONFIG] [ZBOOT_SRC] [DATA_MP] [SLOT]
#   CONFIG    default /etc/device-tree-overlays.conf
#   ZBOOT_SRC default /boot/zboot.img
#   DATA_MP   default /data (OVERLAY_DATA mount); output goes to $DATA_MP/fit/
#   SLOT      optional: A or B → write zboot_merged_a.img / zboot_merged_b.img
#
# Output is under $DATA_MP/fit/ (e.g. /data/fit/) so the path watcher does not
# retrigger on the written FIT (watcher monitors /etc/device-tree-overlays.conf
# and /etc/devicetree). U-Boot loads from fit/* on the OVERLAY_DATA partition.

set -e

CONFIG_FILE="${1:-/etc/device-tree-overlays.conf}"
ZBOOT_SRC="${2:-/boot/zboot.img}"
DATA_MP="${3:-/data}"
SLOT="${4:-}"
# When not passed, try current slot from kernel cmdline (e.g. when run from systemd on booted root)
if [[ -z "$SLOT" ]] && [[ -r /proc/cmdline ]]; then
    read -r _cmdline < /proc/cmdline || true
    for _arg in $_cmdline; do
        if [[ "$_arg" == rauc.slot=A ]]; then SLOT=A; break; fi
        if [[ "$_arg" == rauc.slot=B ]]; then SLOT=B; break; fi
    done
fi
OUTPUT_DIR="$DATA_MP/fit"
if [[ -n "$SLOT" ]]; then
    SLOT_LOWER="$(echo "$SLOT" | tr 'A-Z' 'a-z')"
    OUT_BASENAME="zboot_merged_${SLOT_LOWER}.img"
else
    OUT_BASENAME="zboot_merged.img"
fi
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

if [[ ! -f "$ZBOOT_SRC" ]]; then
    echo "merge-dt-overlays-boot: $ZBOOT_SRC not found" >&2
    exit 1
fi

# Build list of overlay .dtbo files from config (only those in config)
OVERLAY_FILES=()
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line="${raw_line%%#*}"
        line="$(trim "$line")"
        [[ -z "$line" ]] && continue
        if [[ "$line" == /* ]]; then
            overlay_file="$line"
        else
            [[ "$line" != *.dtbo ]] && line="${line}.dtbo"
            if [[ -f "/etc/devicetree/${line}" ]]; then
                overlay_file="/etc/devicetree/${line}"
            elif [[ -f "/boot/devicetree/${line}" ]]; then
                overlay_file="/boot/devicetree/${line}"
            else
                echo "merge-dt-overlays-boot: overlay not found: $line" >&2
                continue
            fi
        fi
        [[ -f "$overlay_file" ]] && OVERLAY_FILES+=( "$overlay_file" )
    done < "$CONFIG_FILE"
fi

# Extract kernel and fdt from FIT (dumpimage -l shows order; typically 0=kernel, 1=fdt)
dumpimage -l "$ZBOOT_SRC" > "$WORKDIR/list.txt" 2>/dev/null || true
dumpimage -i "$ZBOOT_SRC" -p 0 -o "$WORKDIR/kernel" 2>/dev/null || { echo "dumpimage: failed to extract kernel" >&2; exit 1; }
dumpimage -i "$ZBOOT_SRC" -p 1 -o "$WORKDIR/fdt.dtb" 2>/dev/null || { echo "dumpimage: failed to extract fdt" >&2; exit 1; }

# Merge overlays onto base DTB
if [[ ${#OVERLAY_FILES[@]} -gt 0 ]]; then
    if ! command -v fdtoverlay &>/dev/null; then
        echo "merge-dt-overlays-boot: fdtoverlay not found (need dtc with fdtoverlay)" >&2
        exit 1
    fi
    fdtoverlay -i "$WORKDIR/fdt.dtb" -o "$WORKDIR/merged.dtb" "${OVERLAY_FILES[@]}" || { echo "fdtoverlay failed" >&2; exit 1; }
else
    cp "$WORKDIR/fdt.dtb" "$WORKDIR/merged.dtb"
fi

# Repack FIT with kernel + merged DTB. Use a minimal .its; mkimage will hash.
# Compression: check dumpimage list for "Compression" (gzip common).
COMPRESS="none"
grep -q "gzip" "$WORKDIR/list.txt" 2>/dev/null && COMPRESS="gzip"
cat > "$WORKDIR/image.its" << EOF
/dts-v1/;
/ {
    description = "zboot with merged DTB";
    \#address-cells = <1>;
    images {
        kernel {
            data = /incbin/("kernel");
            type = "kernel";
            arch = "arm";
            os = "linux";
            compression = "$COMPRESS";
        };
        fdt {
            data = /incbin/("merged.dtb");
            type = "flat_dt";
            arch = "arm";
            compression = "none";
        };
    };
    configurations {
        default = "conf";
        conf {
            kernel = "kernel";
            fdt = "fdt";
        };
    };
};
EOF

mkimage -f "$WORKDIR/image.its" -A arm "$WORKDIR/zboot_merged.img" -r 2>/dev/null || \
    { echo "mkimage: failed to repack FIT" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
install -m 0644 "$WORKDIR/zboot_merged.img" "$OUTPUT_DIR/$OUT_BASENAME"
echo "merge-dt-overlays-boot: wrote $OUT_BASENAME (${#OVERLAY_FILES[@]} overlays) to $OUTPUT_DIR"
