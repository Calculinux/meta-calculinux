# libplacebo is a hard dependency of mpv 0.40, but nothing on the device
# renders with it (no GPU). Build it without the Vulkan/OpenGL backends and
# lcms so it does not pull libvulkan and friends onto the rootfs.
PACKAGECONFIG:class-target = ""

# Same version as the untrimmed package already in the feed; bump PR so opkg
# upgrades devices that have it installed.
PR = "r1"
