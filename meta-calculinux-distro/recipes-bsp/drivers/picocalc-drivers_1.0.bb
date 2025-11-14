SUMMARY = "PicoCalc hardware drivers"
DESCRIPTION = "Complete set of kernel drivers for PicoCalc including MFD, LCD, keyboard, sound, and power management"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

####### Build with local checkout for development
#inherit module externalsrc
#PV = "1.0"
#EXTERNALSRC = "/work/picocalc-drivers"
#EXTERNALSRC_BUILD = "/work/picocalc-drivers"
#######
####### Build with Github source repo
inherit module
#######

# Skip QA checks that are problematic for all kernel modules
INSANE_SKIP:${PN} += "buildpaths debug-files"
INSANE_SKIP:${PN}-dbg += "buildpaths"

# Define logical package groups - custom packages first, then standard packages
PACKAGES = "${PN}-mfd ${PN}-kbd ${PN}-lcd ${PN}-lcd-drm ${PN}-snd-pwm ${PN}-snd-softpwm ${PN}-dbg ${PN}-src ${PN}-staticdev ${PN}-dev ${PN}-doc ${PN}-locale ${PN}"

# Package descriptions
SUMMARY:${PN}-mfd = "PicoCalc MFD drivers (core, BMS, backlight, keyboard, LED)"
DESCRIPTION:${PN}-mfd = "Complete set of MFD (Multi-Function Device) drivers for PicoCalc including core, battery management, backlight, keyboard, and LED control"

SUMMARY:${PN}-kbd = "PicoCalc legacy keyboard driver"
DESCRIPTION:${PN}-kbd = "GPIO-matrix keyboard driver for PicoCalc (legacy, use MFD keyboard instead)"

SUMMARY:${PN}-lcd-fb = "PicoCalc Legacy FBDev LCD driver"
DESCRIPTION:${PN}-lcd-fb = "ILI9488 framebuffer driver for PicoCalc LCD display"

SUMMARY:${PN}-lcd-drm = "PicoCalc TinyDRM LCD driver"
DESCRIPTION:${PN}-lcd-drm = "DRM/KMS driver for the PicoCalc ILI9488 SPI LCD using TinyDRM"

SUMMARY:${PN}-snd-pwm = "PicoCalc hardware PWM sound driver"
DESCRIPTION:${PN}-snd-pwm = "Hardware PWM-based sound driver for PicoCalc"

SUMMARY:${PN}-snd-softpwm = "PicoCalc software PWM sound driver"
DESCRIPTION:${PN}-snd-softpwm = "Software PWM-based sound driver for PicoCalc"

# Package file assignments - group MFD drivers together
FILES:${PN}-mfd = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_mfd.ko \
                   ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_mfd_bms.ko \
                   ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_mfd_bkl.ko \
                   ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_mfd_kbd.ko \
                   ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_mfd_led.ko"

FILES:${PN}-kbd = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_kbd.ko"
FILES:${PN}-lcd-fb = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/ili9488_fb.ko"
FILES:${PN}-lcd-drm = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/ili9488_drm.ko"
FILES:${PN}-snd-pwm = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_snd_pwm.ko"
FILES:${PN}-snd-softpwm = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/picocalc_snd_softpwm.ko"

# Runtime dependencies - MFD sub-drivers are always loaded together as a unit via the core module
# No inter-package dependencies needed since they're all in one package

# Note: We allow both legacy keyboard and MFD keyboard packages to be installed simultaneously.
# Device tree 'compatible' selection and driver probe order determine which driver binds at runtime.

# Main package pulls in all driver packages for convenience
# Users can still install individual packages if they want specific drivers only
RDEPENDS:${PN} = " \
    ${PN}-lcd-fb \
    ${PN}-lcd-drm \
    ${PN}-snd-pwm \
    ${PN}-snd-softpwm \
    ${PN}-mfd \
"

# Main package itself is empty - all content is in sub-packages
FILES:${PN} = ""
ALLOW_EMPTY:${PN} = "1"

# Build all drivers individually
do_compile() {
    # Use the top-level Makefile to build all modules in the repository
    if [ -f ${S}/Makefile ]; then
        cd ${S}
        make KERNEL_SRC=${STAGING_KERNEL_DIR} KSRC=${STAGING_KERNEL_DIR} all
    else
        bbfatal "Top-level Makefile not found in ${S}"
    fi
}

do_install() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra
    
    # Install all kernel modules
    install -m 0644 ${S}/picocalc_mfd/picocalc_mfd.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_mfd_bms/picocalc_mfd_bms.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_mfd_bkl/picocalc_mfd_bkl.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_mfd_kbd/picocalc_mfd_kbd.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_mfd_led/picocalc_mfd_led.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_kbd/picocalc_kbd.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_lcd_fb/ili9488_fb.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_lcd_drm/ili9488_drm.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_snd-pwm/picocalc_snd_pwm.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/picocalc_snd-softpwm/picocalc_snd_softpwm.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
}

SYSROOT_DIRS += "${datadir}/picocalc"

FILES:${PN}-src += "${datadir}/picocalc/picocalc-luckfox-lyra.dtsi"
