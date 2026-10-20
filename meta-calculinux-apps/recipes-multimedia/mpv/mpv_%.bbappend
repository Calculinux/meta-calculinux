# mpv is only here as libmpv for audio playback (stmps). The device has no
# X11/Wayland and no GPU, so skip every windowing/GL/Vulkan backend and the
# Lua OSD. This also drops the wayland, libxkbcommon, mesa EGL/GBM and
# luajit runtime dependencies.
# mpv 0.40 still requires libass and libplacebo; see their bbappends.
PACKAGECONFIG = "libmpv"

# Same version as the untrimmed package already in the feed; bump PR so opkg
# upgrades devices that have it installed.
PR = "r1"
