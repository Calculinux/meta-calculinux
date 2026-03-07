# Build a single default merged FIT (kernel + DT overlays) at image build time.
# Uses the kernel and FDT deployed by the kernel recipe (fit_kernel, fit_fdt.dtb);
# no extraction from zboot.img. Installs:
#   /boot/zboot_merged.img - fallback FIT (U-Boot when both A and B on /data/fit/ fail)
#   /boot/fit_kernel, /boot/fit_fdt.dtb, /boot/fit_compression.txt - base components
# so merge-dt-overlays-boot.sh can build user-merged FITs from the base DTB (no extraction).

SUMMARY = "Default merged zboot FIT (read-only fallback)"
DESCRIPTION = "Builds zboot_merged.img with default device tree overlays; \
installed in /boot/. Fallback when both A and B on /data/fit/ fail."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

COMPATIBLE_MACHINE = "luckfox-lyra"

# Overlay names (without .dtbo) to apply by default. Empty = no overlays.
DEFAULT_DT_OVERLAYS ?= "sx1262-lora"

DEPENDS = "virtual/kernel picocalc-dt-overlays u-boot-tools-native dtc-native"
do_install[depends] += "virtual/kernel:do_deploy"

# S = ${WORKDIR} is not allowed since Yocto 5.1 (insane.bbclass). Use UNPACKDIR + placeholder.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI = "file://dummy"
S = "${UNPACKDIR}"

do_install() {
    DEPLOY="${DEPLOY_DIR_IMAGE}"
    KERNEL_SRC="${DEPLOY}/fit_kernel"
    FDT_SRC="${DEPLOY}/fit_fdt.dtb"
    COMPRESS_FILE="${DEPLOY}/fit_compression.txt"
    OVERLAY_SRCDIR="${STAGING_DIR_TARGET}/boot/devicetree"
    OUTDIR="${D}/boot"
    install -d "$OUTDIR"

    [ -f "$KERNEL_SRC" ] || bbfatal "default-merged-fit: $KERNEL_SRC not found (kernel must deploy fit_kernel)"
    [ -f "$FDT_SRC" ] || bbfatal "default-merged-fit: $FDT_SRC not found (kernel must deploy fit_fdt.dtb)"

    WORKDIR_MERGE="${WORKDIR}/merge"
    rm -rf "$WORKDIR_MERGE"
    mkdir -p "$WORKDIR_MERGE"
    cp "$KERNEL_SRC" "$WORKDIR_MERGE/kernel"
    cp "$FDT_SRC" "$WORKDIR_MERGE/fdt.dtb"

    COMPRESS="none"
    [ -f "$COMPRESS_FILE" ] && COMPRESS=$(cat "$COMPRESS_FILE") || true

    OVERLAY_FILES=""
    for name in ${DEFAULT_DT_OVERLAYS}; do
        f="$OVERLAY_SRCDIR/${name}.dtbo"
        if [ -f "$f" ]; then
            OVERLAY_FILES="$OVERLAY_FILES $f"
        fi
    done

    if [ -n "$OVERLAY_FILES" ]; then
        command -v fdtoverlay >/dev/null 2>&1 || bbfatal "fdtoverlay not found (need dtc-native with fdtoverlay)"
        if ! fdtoverlay -i "$WORKDIR_MERGE/fdt.dtb" -o "$WORKDIR_MERGE/merged.dtb" $OVERLAY_FILES 2>"$WORKDIR_MERGE/fdtoverlay.stderr"; then
            bbfatal "fdtoverlay failed: $(cat "$WORKDIR_MERGE/fdtoverlay.stderr" 2>/dev/null || echo 'no stderr')"
        fi
    else
        cp "$WORKDIR_MERGE/fdt.dtb" "$WORKDIR_MERGE/merged.dtb"
    fi

    cat > "$WORKDIR_MERGE/image.its" << EOF
/dts-v1/;
/ {
    description = "zboot with merged DTB (default)";
    \#address-cells = <1>;
    images {
        kernel {
            data = /incbin/("$WORKDIR_MERGE/kernel");
            type = "kernel";
            arch = "arm";
            os = "linux";
            compression = "$COMPRESS";
        };
        fdt {
            data = /incbin/("$WORKDIR_MERGE/merged.dtb");
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
    if ! mkimage -f "$WORKDIR_MERGE/image.its" -A arm "$WORKDIR_MERGE/zboot_merged.img" -r 2>"$WORKDIR_MERGE/mkimage.stderr"; then
        bbfatal "mkimage: failed to repack FIT: $(cat "$WORKDIR_MERGE/mkimage.stderr" 2>/dev/null || echo 'no stderr')"
    fi

    install -m 0644 "$WORKDIR_MERGE/zboot_merged.img" "$OUTDIR/zboot_merged.img"

    # Base FIT components for merge-dt-overlays-boot.sh (base DTB, no overlays)
    install -m 0644 "$WORKDIR_MERGE/kernel" "$OUTDIR/fit_kernel"
    install -m 0644 "$WORKDIR_MERGE/fdt.dtb" "$OUTDIR/fit_fdt.dtb"
    echo -n "$COMPRESS" > "$OUTDIR/fit_compression.txt"
}

FILES:${PN} = "/boot/zboot_merged.img /boot/fit_kernel /boot/fit_fdt.dtb /boot/fit_compression.txt"
PACKAGES = "${PN}"
