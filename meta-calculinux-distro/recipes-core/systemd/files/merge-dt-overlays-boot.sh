#!/bin/bash
# Merge device tree overlays into the base DTB from /boot/fit_*, then repack
# the FIT and write to OVERLAY_DATA so U-Boot can load it at next boot.
#
# One merged FIT per RAUC slot: zboot_merged_a.img / zboot_merged_b.img.
# U-Boot loads the FIT matching rauc.slot, then /boot/zboot_merged.img.
#
# Usage: merge-dt-overlays-boot.sh [CONFIG] [DATA_MP] [SLOT]
#   CONFIG   default /etc/device-tree-overlays.conf
#   DATA_MP  default /data (OVERLAY_DATA mount); output goes to $DATA_MP/fit/
#   SLOT     A or B (default: rauc.slot= from /proc/cmdline, else A)

resolve_rauc_slot() {
    local slot="$1"
    local cmdline="$2"
    case "$slot" in
        A|a) printf '%s' A; return ;;
        B|b) printf '%s' B; return ;;
    esac
    for arg in $cmdline; do
        case "$arg" in
            rauc.slot=A|rauc.slot=a) printf '%s' A; return ;;
            rauc.slot=B|rauc.slot=b) printf '%s' B; return ;;
        esac
    done
    printf '%s' A
}

merged_fit_name() {
    case "$(resolve_rauc_slot "$1" "$2")" in
        B) printf '%s' zboot_merged_b.img ;;
        *) printf '%s' zboot_merged_a.img ;;
    esac
}

fit_kernel_stamp() {
    sha256sum "$1" | awk '{print $1}'
}

stamp_matches() {
    [ -f "$1" ] && [ -f "$2" ] || return 1
    [ "$(fit_kernel_stamp "$1")" = "$(cat "$2")" ]
}

if [ "${MERGE_DT_OVERLAYS_LIB:-}" = 1 ]; then
    return 0 2>/dev/null || exit 0
fi

set -e

CONFIG_FILE="${1:-/etc/device-tree-overlays.conf}"
DATA_MP="${2:-/data}"
CMDLINE=""
[[ -r /proc/cmdline ]] && read -r CMDLINE < /proc/cmdline || true
SLOT="$(resolve_rauc_slot "${3:-}" "$CMDLINE")"
OUT_BASENAME="$(merged_fit_name "$SLOT" "")"
OUTPUT_DIR="$DATA_MP/fit"
STAMP_FILE="$OUTPUT_DIR/kernel-${SLOT}.stamp"

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

FIT_KERNEL="/boot/fit_kernel"
FIT_FDT="/boot/fit_fdt.dtb"
FIT_COMPRESS_FILE="/boot/fit_compression.txt"

if [[ ! -f "$FIT_KERNEL" ]] || [[ ! -f "$FIT_FDT" ]]; then
    echo "merge-dt-overlays-boot: required $FIT_KERNEL and $FIT_FDT not found (install default-merged-fit)" >&2
    exit 1
fi

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

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

cp "$FIT_KERNEL" kernel
cp "$FIT_FDT" fdt.dtb
COMPRESS="none"
[[ -f "$FIT_COMPRESS_FILE" ]] && read -r COMPRESS < "$FIT_COMPRESS_FILE" || true

if [[ ${#OVERLAY_FILES[@]} -gt 0 ]]; then
    if ! command -v fdtoverlay &>/dev/null; then
        echo "merge-dt-overlays-boot: fdtoverlay not found (need dtc with fdtoverlay)" >&2
        exit 1
    fi
    fdtoverlay -i fdt.dtb -o merged.dtb "${OVERLAY_FILES[@]}" || { echo "merge-dt-overlays-boot: fdtoverlay failed" >&2; exit 1; }
else
    cp fdt.dtb merged.dtb
fi

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

mkimage -f image.its -A arm zboot_merged.img -r || \
    { echo "merge-dt-overlays-boot: mkimage failed to repack FIT" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
install -m 0644 zboot_merged.img "$OUTPUT_DIR/$OUT_BASENAME"
fit_kernel_stamp "$FIT_KERNEL" > "$STAMP_FILE"
echo "merge-dt-overlays-boot: wrote $OUT_BASENAME for RAUC slot $SLOT (${#OVERLAY_FILES[@]} overlays)"
