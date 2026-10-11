#!/bin/bash
# Merge device tree overlays into the base DTB from /boot/fit_*, then repack
# the FIT and write to OVERLAY_DATA so U-Boot can load it at next boot.
#
# One merged FIT per RAUC slot: zboot_merged_a.img / zboot_merged_b.img.
# U-Boot loads the FIT matching rauc.slot, then /boot/zboot_merged.img.
#
# Usage: merge-dt-overlays-boot.sh [CONFIG] [DATA_MP] [SLOT] [ROOT]
#   CONFIG   default /etc/device-tree-overlays.conf; always read from the live
#            system (the user's current overlay selection)
#   DATA_MP  default /data (OVERLAY_DATA mount); output goes to $DATA_MP/fit/
#   SLOT     A or B (default: rauc.slot= from /proc/cmdline, else A)
#   ROOT     anchor for the kernel/FDT/overlay INPUTS. Default empty = the
#            live system's own /boot, /etc and /lib/firmware. The RAUC
#            post-install merge passes the freshly installed slot's rootfs
#            mount, pairing the new slot's kernel with its own .dtbo files
#            (issue #239: overlays missing on the first boot after an
#            update). For overlay entries, each search location is tried
#            under ROOT first, then on the live system - user-added .dtbo
#            files live on the persistent /data overlay layer, which the
#            raw slot rootfs does not expose. CONFIG and DATA_MP never are
#            anchored.

# Load stamp helpers (fit_kernel_stamp, stamp_matches, stamp_should_drop)
_FIT_STAMP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=fit-stamp.sh
. "${_FIT_STAMP_DIR}/fit-stamp.sh"

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

# Locate one overlay entry (a name or an absolute path) from the config.
# With ROOT set (merge for a freshly installed slot) every search location
# is tried under ROOT first - the new slot's .dtbo files match its own base
# DTB - then on the live system, where user-added files persist across
# slots on the /data overlay layer. Prints the path found; fails otherwise.
resolve_overlay() {
    local line="$1" loc
    if [[ "$line" == /* ]]; then
        if [[ -n "$ROOT" && -f "$ROOT$line" ]]; then
            printf '%s' "$ROOT$line"
            return 0
        fi
        [[ -f "$line" ]] || return 1
        printf '%s' "$line"
        return 0
    fi
    [[ "$line" != *.dtbo ]] && line="${line}.dtbo"
    for loc in "/etc/devicetree/$line" "/boot/devicetree/$line" "/lib/firmware/overlays/$line"; do
        if [[ -n "$ROOT" && -f "$ROOT$loc" ]]; then
            printf '%s' "$ROOT$loc"
            return 0
        fi
        if [[ -f "$loc" ]]; then
            printf '%s' "$loc"
            return 0
        fi
    done
    return 1
}

if [ "${MERGE_DT_OVERLAYS_LIB:-}" = 1 ]; then
    return 0 2>/dev/null || exit 0
fi

set -e

CONFIG_FILE="${1:-/etc/device-tree-overlays.conf}"
DATA_MP="${2:-/data}"
ROOT="${4:-}"
# Anchor input paths at ROOT ("" or a slot rootfs mount, e.g. "/" or
# /var/run/rauc/mounts/rootfs.1); strip the trailing slash so the paths stay
# clean.
case "$ROOT" in
    /) ROOT="" ;;
    */) ROOT="${ROOT%/}" ;;
esac
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

# Anchored at ROOT: the live system's /boot by default, the new slot's /boot
# when refreshing the merged FIT for a freshly installed slot.
FIT_KERNEL="$ROOT/boot/fit_kernel"
FIT_FDT="$ROOT/boot/fit_fdt.dtb"
FIT_COMPRESS_FILE="$ROOT/boot/fit_compression.txt"
# Board load addresses (match the board's U-Boot memory layout); written by
# default-merged-fit from the machine configuration.
FIT_LOADADDR_FILE="$ROOT/boot/fit_loadaddr.env"

if [[ ! -f "$FIT_KERNEL" ]] || [[ ! -f "$FIT_FDT" ]] || [[ ! -f "$FIT_LOADADDR_FILE" ]]; then
    echo "merge-dt-overlays-boot: required $FIT_KERNEL, $FIT_FDT and $FIT_LOADADDR_FILE not found (install default-merged-fit)" >&2
    exit 1
fi
KERNEL_LOAD_ADDR=""
FDT_LOAD_ADDR=""
# shellcheck source=/dev/null
. "$FIT_LOADADDR_FILE"
if [[ -z "$KERNEL_LOAD_ADDR" ]] || [[ -z "$FDT_LOAD_ADDR" ]]; then
    echo "merge-dt-overlays-boot: $FIT_LOADADDR_FILE does not set KERNEL_LOAD_ADDR and FDT_LOAD_ADDR" >&2
    exit 1
fi

OVERLAY_FILES=()
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line="${raw_line%%#*}"
        line="$(trim "$line")"
        [[ -z "$line" ]] && continue
        if ! overlay_file="$(resolve_overlay "$line")"; then
            echo "merge-dt-overlays-boot: overlay not found: $line" >&2
            exit 1
        fi
        OVERLAY_FILES+=( "$overlay_file" )
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

# Use a quoted heredoc delimiter so BitBake/shell do not mangle #address-cells.
# load/entry must match the board U-Boot ram layout (fit_loadaddr.env).
cat > image.its << EOF
/dts-v1/;
/ {
    description = "zboot with merged DTB";
    #address-cells = <1>;
    images {
        kernel {
            data = /incbin/("kernel");
            type = "kernel";
            arch = "arm";
            os = "linux";
            compression = "$COMPRESS";
            load = <$KERNEL_LOAD_ADDR>;
            entry = <$KERNEL_LOAD_ADDR>;
        };
        fdt {
            data = /incbin/("merged.dtb");
            type = "flat_dt";
            arch = "arm";
            compression = "none";
            load = <$FDT_LOAD_ADDR>;
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
# Atomic replace: temp then rename, then stamp (crash cannot leave torn FIT + matching stamp).
# Use cp/chmod — BusyBox images often have no `install`.
cp zboot_merged.img "$OUTPUT_DIR/${OUT_BASENAME}.tmp"
chmod 0644 "$OUTPUT_DIR/${OUT_BASENAME}.tmp"
mv -f "$OUTPUT_DIR/${OUT_BASENAME}.tmp" "$OUTPUT_DIR/$OUT_BASENAME"
fit_kernel_stamp "$FIT_KERNEL" > "$STAMP_FILE"
echo "merge-dt-overlays-boot: wrote $OUT_BASENAME for RAUC slot $SLOT (${#OVERLAY_FILES[@]} overlays)"
