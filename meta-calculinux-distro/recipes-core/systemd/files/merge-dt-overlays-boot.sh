#!/bin/bash
# Merge device tree overlays (from /etc/device-tree-overlays.conf and
# /etc/devicetree/) into the base DTB from /boot/fit_*, then repack the FIT
# and write to OVERLAY_DATA so U-Boot can load it at next boot.
#
# Requires /boot/fit_kernel, /boot/fit_fdt.dtb (and /boot/fit_compression.txt)
# from default-merged-fit.
#
# When SLOT is set (A or B), output is zboot_merged_<slot>.img so each root
# slot has its own merged FIT; U-Boot loads the one matching the chosen slot.
# When SLOT is unset (legacy), output is zboot_merged.img (single file).
#
# Config: /etc/device-tree-overlays.conf (same format as load-dt-overlays.sh).
# Overlays: /etc/devicetree/*.dtbo and /boot/devicetree/*.dtbo; only those
# listed in the config are applied.
#
# Usage: merge-dt-overlays-boot.sh [CONFIG] [DATA_MP] [SLOT]
#   CONFIG   default /etc/device-tree-overlays.conf
#   DATA_MP  default /data (OVERLAY_DATA mount); output goes to $DATA_MP/fit/
#   SLOT     optional: A or B → write zboot_merged_a.img / zboot_merged_b.img
#
# Output is under $DATA_MP/fit/ (e.g. /data/fit/) so the path watcher does not
# retrigger on the written FIT (watcher monitors /etc/device-tree-overlays.conf
# and /etc/devicetree). U-Boot loads from fit/* on the OVERLAY_DATA partition.

set -e

CONFIG_FILE="${1:-/etc/device-tree-overlays.conf}"
DATA_MP="${2:-/data}"
SLOT="${3:-}"
# When not passed, try current slot from kernel cmdline (e.g. when run from systemd on booted root)
if [[ -z "$SLOT" ]] && [[ -r /proc/cmdline ]]; then
    read -r _cmdline < /proc/cmdline || true
    for _arg in $_cmdline; do
        if [[ "$_arg" == rauc.slot=A ]]; then SLOT=A; break; fi
        if [[ "$_arg" == rauc.slot=B ]]; then SLOT=B; break; fi
    done
fi
OUTPUT_DIR="$DATA_MP/fit"
# Write to the FIT slot we are NOT currently booting from; next boot will use this one
FIT_SLOT="$(fw_printenv -n FIT_SLOT 2>/dev/null || echo A)"
if [[ "$FIT_SLOT" == "A" ]]; then
    OUT_BASENAME="zboot_merged_b.img"
    NEXT_FIT_SLOT="B"
elif [[ "$FIT_SLOT" == "B" ]]; then
    OUT_BASENAME="zboot_merged_a.img"
    NEXT_FIT_SLOT="A"
else
    OUT_BASENAME="zboot_merged_a.img"
    NEXT_FIT_SLOT="A"
fi
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
# All extraction and repack steps use CWD for relative paths; run from WORKDIR.
cd "$WORKDIR"

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Base FIT components in /boot/ (from default-merged-fit)
FIT_KERNEL="/boot/fit_kernel"
FIT_FDT="/boot/fit_fdt.dtb"
FIT_COMPRESS_FILE="/boot/fit_compression.txt"

if [[ ! -f "$FIT_KERNEL" ]] || [[ ! -f "$FIT_FDT" ]]; then
    echo "merge-dt-overlays-boot: required $FIT_KERNEL and $FIT_FDT not found (install default-merged-fit)" >&2
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

# Copy base kernel and DTB from /boot/
cp "$FIT_KERNEL" kernel
cp "$FIT_FDT" fdt.dtb
COMPRESS="none"
[[ -f "$FIT_COMPRESS_FILE" ]] && read -r COMPRESS < "$FIT_COMPRESS_FILE" || true

# Merge overlays onto base DTB
if [[ ${#OVERLAY_FILES[@]} -gt 0 ]]; then
    if ! command -v fdtoverlay &>/dev/null; then
        echo "merge-dt-overlays-boot: fdtoverlay not found (need dtc with fdtoverlay)" >&2
        exit 1
    fi
    fdtoverlay -i fdt.dtb -o merged.dtb "${OVERLAY_FILES[@]}" || { echo "merge-dt-overlays-boot: fdtoverlay failed" >&2; exit 1; }
else
    cp fdt.dtb merged.dtb
fi

# Repack FIT with kernel + merged DTB. Use a minimal .its; mkimage will hash.
# COMPRESS from /boot/fit_compression.txt.
cat > image.its << EOF
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

mkimage -f image.its -A arm zboot_merged.img -r 2>/dev/null || \
    { echo "merge-dt-overlays-boot: mkimage failed to repack FIT" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
install -m 0644 zboot_merged.img "$OUTPUT_DIR/$OUT_BASENAME"
fw_setenv FIT_SLOT "$NEXT_FIT_SLOT" 2>/dev/null || true
echo "merge-dt-overlays-boot: wrote $OUT_BASENAME (${#OVERLAY_FILES[@]} overlays); set FIT_SLOT=$NEXT_FIT_SLOT for next boot"
