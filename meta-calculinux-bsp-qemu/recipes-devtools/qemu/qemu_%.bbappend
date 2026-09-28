# nativesdk-qemu is bundled into the calculinux-emulator AppImage: only the
# Arm system emulator is needed, and the SDL window renders a 320x320
# framebuffer in software, so skip the Mesa/virglrenderer stack.
QEMU_TARGETS:class-nativesdk = "arm"
PACKAGECONFIG:remove:class-nativesdk = "virglrenderer epoxy"
