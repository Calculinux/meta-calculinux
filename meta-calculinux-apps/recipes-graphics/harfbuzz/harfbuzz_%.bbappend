# The cairo option only builds the hb-view/hb-shape test tools. Without it
# libharfbuzz (and so libass, via mpv) no longer drags cairo and its X/pixman
# dependency chain onto the device.
PACKAGECONFIG:remove:class-target = "cairo"

# Same version as the untrimmed package already in the feed; bump PR so opkg
# upgrades devices that have it installed.
PR = "r1"
