# Build a single default merged FIT (zboot + DT overlays) at image build time.
# Installed as /boot/zboot_merged.img on the read-only root. U-Boot uses it only
# when both /data/fit/zboot_merged_a.img and _b.img have failed to boot.

SUMMARY = "Default merged zboot FIT (read-only fallback)"
DESCRIPTION = "Builds zboot_merged.img with default device tree overlays; \
installed in /boot/. Fallback when both A and B on /data/fit/ fail."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

COMPATIBLE_MACHINE = "luckfox-lyra"

# Overlay names (without .dtbo) to apply by default. Empty = no overlays.
DEFAULT_DT_OVERLAYS ?= "sx1262-lora"

DEPENDS = "virtual/kernel picocalc-dt-overlays u-boot-tools-native"
do_install[depends] += "virtual/kernel:do_deploy"
DEPENDS += "dtc-native"

# S = ${WORKDIR} is not allowed since Yocto 5.1 (insane.bbclass). Use UNPACKDIR + placeholder.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI = "file://dummy"
S = "${UNPACKDIR}"

do_install() {
    ZBOOT="${DEPLOY_DIR_IMAGE}/zboot.img"
    OVERLAY_SRCDIR="${STAGING_DIR_TARGET}/boot/devicetree"
    OUTDIR="${D}/boot"
    install -d "$OUTDIR"

    if [ ! -f "$ZBOOT" ]; then
        bbfatal "default-merged-fit: $ZBOOT not found (kernel deploy missing?)"
    fi

    WORKDIR_MERGE="${WORKDIR}/merge"
    rm -rf "$WORKDIR_MERGE"
    mkdir -p "$WORKDIR_MERGE"

    dumpimage -l "$ZBOOT" > "$WORKDIR_MERGE/list.txt" 2>/dev/null || true
    dumpimage -i "$ZBOOT" -p 0 -o "$WORKDIR_MERGE/kernel" 2>/dev/null || bbfatal "dumpimage: failed to extract kernel"
    dumpimage -i "$ZBOOT" -p 1 -o "$WORKDIR_MERGE/fdt.dtb" 2>/dev/null || bbfatal "dumpimage: failed to extract fdt"

    OVERLAY_FILES=""
    for name in ${DEFAULT_DT_OVERLAYS}; do
        f="$OVERLAY_SRCDIR/${name}.dtbo"
        if [ -f "$f" ]; then
            OVERLAY_FILES="$OVERLAY_FILES $f"
        fi
    done

    if [ -n "$OVERLAY_FILES" ] && command -v fdtoverlay >/dev/null 2>&1; then
        fdtoverlay -i "$WORKDIR_MERGE/fdt.dtb" -o "$WORKDIR_MERGE/merged.dtb" $OVERLAY_FILES || bbfatal "fdtoverlay failed"
    else
        cp "$WORKDIR_MERGE/fdt.dtb" "$WORKDIR_MERGE/merged.dtb"
    fi

    COMPRESS="none"
    grep -q "gzip" "$WORKDIR_MERGE/list.txt" 2>/dev/null && COMPRESS="gzip"
    cat > "$WORKDIR_MERGE/image.its" << EOF
/dts-v1/;
/ {
    description = "zboot with merged DTB (default)";
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
    mkimage -f "$WORKDIR_MERGE/image.its" -A arm "$WORKDIR_MERGE/zboot_merged.img" -r 2>/dev/null || bbfatal "mkimage: failed to repack FIT"

    install -m 0644 "$WORKDIR_MERGE/zboot_merged.img" "$OUTDIR/zboot_merged.img"
}

FILES:${PN} = "/boot/zboot_merged.img"
PACKAGES = "${PN}"
