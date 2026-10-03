# nativesdk-qemu is bundled into the calculinux-emulator AppImage: only the
# Arm system emulator is needed, and the SDL window renders a 320x320
# framebuffer in software, so skip the Mesa/virglrenderer stack.
QEMU_TARGETS:class-nativesdk = "arm"
PACKAGECONFIG:remove:class-nativesdk = "virglrenderer epoxy"

# "-display sdl,scale=<n>": the emulator opens its window at a multiple of
# the 320x320 panel (AppRun's --scale).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:class-nativesdk = " file://0001-ui-sdl2-add-a-scale-option-for-the-window-size.patch"
