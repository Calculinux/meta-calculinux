# Needed by nativesdk SDL's Wayland backend in the calculinux-emulator
# AppImage. Keymap data (xkeyboard-config) comes from the host at runtime
# (the launcher sets XKB_CONFIG_ROOT), so build without the X11 extension
# that would pull it in.
BBCLASSEXTEND += "nativesdk"
PACKAGECONFIG:remove:class-nativesdk = "x11"
