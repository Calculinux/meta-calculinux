FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LICENSE = "GPL-2.0-only"

SRCREV = "815d6a4af7589b0da6cc765658913d05fe550965"

SRC_URI = " \
    git://github.com/Calculinux/luckfox-linux-6.1-rk3506.git;protocol=https;nobranch=1 \
    file://base-configs.cfg \
    file://display.cfg \
    file://wifi.cfg \
    file://dto.cfg \
    file://rauc.cfg \
    file://cgroups.cfg \
    file://fonts.cfg \
    file://led.cfg \
    file://removed.cfg \
    file://utf8.cfg \
    file://filesystems.cfg \
    file://usb-gadget.cfg \
    file://audio-i2s.cfg \
    file://mmc-spi-fix-nullpointer-on-shutdown.patch \
    file://0001-of-configfs-overlay-interface.patch \
    file://depmod-skip-when-echo.patch \
"

KERNEL_CONFIG_FRAGMENTS += " \
    base-configs.cfg \
    display.cfg \
    wifi.cfg \
    dto.cfg \
    rauc.cfg \
    cgroups.cfg \
    fonts.cfg \
    led.cfg \
    removed.cfg \
    utf8.cfg \
    filesystems.cfg \
    usb-gadget.cfg \
    audio-i2s.cfg \
"

DEPENDS += "gzip"
KBUILD_DEFCONFIG = "rk3506_luckfox_defconfig"

ROCKCHIP_KERNEL_IMAGES = "0"
ROCKCHIP_KERNEL_COMPRESSED = "1"
KERNEL_IMAGETYPES = "zboot.img"

# --- Device Tree Overlay Symbol Support ---
#
# Runtime ConfigFS overlays need a __symbols__ node in the base DTB so the
# kernel can resolve phandle label references (e.g. &i2c2, &pinctrl) at
# overlay-apply time.
#
# However, compiling with DTC's -@ flag adds __symbols__ for EVERY labelled
# node. On the RK3506, the RMIO pinctrl DTSI alone defines ~3,100 labels
# (all marked /omit-if-no-ref/). With -@, DTC keeps every one of them,
# inflating the DTB from ~75 KB to ~536 KB.  That DTB is too large for the
# vendor U-Boot's FDT memory region and corrupts the devicetree at boot.
#
# Solution: two-pass build.
#   Pass 1 – normal compile (no -@): produces a compact DTB where
#            /omit-if-no-ref/ correctly strips unused RMIO nodes.
#   Pass 2 – recompile the DTB only with -@ into a temp file, extract the
#            paths for a curated set of symbols, and inject them into the
#            compact DTB.  Then rebuild the Rockchip .img so the trimmed
#            DTB is re-packaged into zboot.img.
#
# Symbol list: three sources merged together:
#   1. overlay-symbols.txt – auto-generated from picocalc-drivers overlays
#   2. DT_OVERLAY_SYMBOLS_BASE – common platform peripherals for end-user overlays
#   3. DT_OVERLAY_SYMBOLS_EXTRA – manual additions for board-specific overlays

DT_OVERLAY_SYMBOLS_BASE ?= "\
    can0 can1 \
    cru \
    cpu0 \
    dsi dsi_dphy dsi_in_vop \
    fspi \
    gmac0 gmac1 mdio0 mdio1 \
    gpio0 gpio1 gpio2 gpio3 gpio4 \
    i2c0 i2c1 i2c2 i2c3 \
    mmc \
    pcfg_pull_none pcfg_pull_up pcfg_pull_down \
    pinctrl \
    pwm0_4ch_0 pwm0_4ch_1 pwm0_4ch_2 pwm0_4ch_3 \
    rga2 \
    sai0 sai1 sai2 \
    saradc \
    spi0 spi1 \
    tsadc \
    uart0 uart1 uart2 uart3 uart4 uart5 \
    uart0m0_xfer uart1m0_xfer uart2m0_xfer uart3m0_xfer uart4m0_xfer uart5m0_xfer \
    usb20_otg0 usb20_otg1 usb2phy u2phy_otg0 u2phy_otg1 \
    vcc_3v3 vcc_1v8 vcc_sys vdd_cpu \
    vop vop_out \
"

DT_OVERLAY_SYMBOLS_EXTRA ?= ""

# Pass 1 – build everything without -@ (compact DTB)
do_compile:prepend() {
    export DTC_FLAGS=""
}

# Pass 2 – selective symbol injection + repackage
do_compile:append() {
    DTB_NAME="${@d.getVar('KERNEL_DEVICETREE').replace('.dtb','')}"
    DTB_FILE="${B}/arch/${ARCH}/boot/dts/${DTB_NAME}.dtb"

    if [ ! -f "${DTB_FILE}" ]; then
        bbwarn "DTB not found at ${DTB_FILE}, skipping symbol injection"
        return
    fi

    # Build the combined symbol list: base platform + auto-generated + extras
    OVERLAY_SYMS_FILE="${RECIPE_SYSROOT}${datadir}/picocalc/overlay-symbols.txt"
    SYMBOLS="${DT_OVERLAY_SYMBOLS_BASE}"
    if [ -f "${OVERLAY_SYMS_FILE}" ]; then
        SYMBOLS="${SYMBOLS} $(cat "${OVERLAY_SYMS_FILE}" | tr '\n' ' ')"
        bbnote "Loaded overlay symbols from ${OVERLAY_SYMS_FILE}"
    else
        bbwarn "overlay-symbols.txt not found in sysroot"
    fi
    SYMBOLS="${SYMBOLS} ${DT_OVERLAY_SYMBOLS_EXTRA}"

    # De-duplicate
    SYMBOLS=$(echo ${SYMBOLS} | tr ' ' '\n' | sort -u | tr '\n' ' ')

    if [ -z "$(echo ${SYMBOLS} | tr -d ' ')" ]; then
        bbnote "No overlay symbols to inject, skipping symbol pass"
        return
    fi

    bbnote "=== Selective DT overlay symbol injection ==="
    bbnote "Symbols to inject: ${SYMBOLS}"
    bbnote "Original DTB size: $(stat -c %s ${DTB_FILE}) bytes"

    # Save the compact (no-symbols) DTB
    cp "${DTB_FILE}" "${DTB_FILE}.compact"

    # Rebuild DTB with -@ using dtc directly. The kernel make target for this DTB
    # is not in dtb-y (Rockchip zboot flow builds it separately), so we preprocess
    # the DTS with cpp and compile with dtc -@ to get __symbols__.
    bbnote "Recompiling DTB with -@ to extract symbol paths..."
    DTS_SRC="${S}/arch/${ARCH}/boot/dts/${DTB_NAME}.dts"
    DTS_PP="${DTB_FILE}.pp.dts"
    DTB_FULL="${DTB_FILE}.full-symbols"

    ${BUILD_CPP} -nostdinc \
        -I"${S}/scripts/dtc/include-prefixes" \
        -I"${S}/arch/${ARCH}/boot/dts" \
        -I"${S}/include" \
        -undef -D__DTS__ -x assembler-with-cpp \
        "${DTS_SRC}" -o "${DTS_PP}"
    dtc -@ -i "${S}/arch/${ARCH}/boot/dts" \
        -i "${S}/scripts/dtc/include-prefixes" \
        -I dts -O dtb -o "${DTB_FULL}" "${DTS_PP}"
    rm -f "${DTS_PP}"

    bbnote "Full-symbols DTB size: $(stat -c %s ${DTB_FULL}) bytes"

    # Restore the compact DTB
    cp "${DTB_FILE}.compact" "${DTB_FILE}"

    # Create __symbols__ node in the compact DTB
    fdtput -c "${DTB_FILE}" /__symbols__ 2>/dev/null || true

    # Copy only whitelisted symbol entries from the full DTB
    SYMS_ADDED=0
    SYMS_MISSING=0
    for sym in ${SYMBOLS}; do
        path=$(fdtget -ts "${DTB_FULL}" /__symbols__ "${sym}" 2>/dev/null) || true
        if [ -n "${path}" ]; then
            fdtput -ts "${DTB_FILE}" /__symbols__ "${sym}" "${path}"
            SYMS_ADDED=$(expr $SYMS_ADDED + 1)
        else
            bbwarn "  Symbol '${sym}' not found in full DTB (may not exist in this SoC)"
            SYMS_MISSING=$(expr $SYMS_MISSING + 1)
        fi
    done

    bbnote "Injected ${SYMS_ADDED} symbols (${SYMS_MISSING} not found)"
    bbnote "Trimmed DTB size: $(stat -c %s ${DTB_FILE}) bytes"

    # Clean up temp files
    rm -f "${DTB_FILE}.compact" "${DTB_FULL}"

    # Rebuild the Rockchip .img with the trimmed DTB
    bbnote "Repackaging kernel image with trimmed DTB..."
    IMGTYPE="${@(d.getVar('KERNEL_IMAGETYPE_FOR_MAKE') or 'zboot.img').strip()}"
    oe_runmake ${IMGTYPE} ${KERNEL_EXTRA_ARGS}
    bbnote "=== Symbol injection complete ==="
}

DEPENDS += "dtc-native"

# Copy PicoCalc device tree from devicetree helper recipe
do_prepare_kernel_picocalc() {
    PICOCALC_DT_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/picocalc-luckfox-lyra.dtsi"
    PICOCALC_BOARD_DTSI_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/rk3506-luckfox-lyra.dtsi"
    PICOCALC_BOARD_DTS_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/rk3506g-luckfox-lyra.dts"
    install -d ${S}/arch/${ARCH}/boot/dts
    cp "${PICOCALC_DT_SOURCE}" "${S}/arch/${ARCH}/boot/dts/picocalc-luckfox-lyra.dtsi"
    cp "${PICOCALC_BOARD_DTSI_SOURCE}" "${S}/arch/${ARCH}/boot/dts/rk3506-luckfox-lyra.dtsi"
    cp "${PICOCALC_BOARD_DTS_SOURCE}" "${S}/arch/${ARCH}/boot/dts/rk3506g-luckfox-lyra.dts"
}

addtask prepare_kernel_picocalc after do_kernel_checkout before do_kernel_configme
do_prepare_kernel_picocalc[depends] += "picocalc-devicetree:do_populate_sysroot"

do_install:append() {
    # Remove kernel image formats that are not needed in the device image
    rm -f ${D}/boot/Image
    rm -f ${D}/boot/Image-*

    gzip -kf "${B}/.config"
    install -D -m 0644  "${B}/.config.gz" "${D}${datadir}/kernel/config.gz"
}

FILES:${KERNEL_PACKAGE_NAME}-base += "${datadir}/kernel"
