# Expand dtc to explicitly package all tools built by meson when tools are enabled.
# Upstream only splits out convert-dtsv0, ftdump, dtdiff into dtc-misc; the
# overlay/query tools (fdtoverlay, fdtget, fdtput) and fdtdump are left in the
# main package. Meson installs "fdtdump" (upstream recipe typo: "ftdump").
# We fix dtc-misc and ensure fdtoverlay/fdtget/fdtput are in the main package
# so merge-dt-overlays-boot and other consumers only need RDEPENDS on "dtc".
# Requires PACKAGECONFIG += "tools" (default in upstream).

# Fix upstream typo: meson builds fdtdump, not ftdump
FILES:${PN}-misc = "${bindir}/convert-dtsv0 ${bindir}/fdtdump ${bindir}/dtdiff"

# Ensure overlay/query tools are in main package (single dependency for images)
FILES:${PN} += " \
    ${bindir}/fdtoverlay \
    ${bindir}/fdtget \
    ${bindir}/fdtput \
"
