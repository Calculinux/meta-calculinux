# Expand dtc to explicitly package all tools built by meson when tools are enabled.
# Upstream only splits out convert-dtsv0, ftdump, dtdiff into dtc-misc; the
# overlay/query tools (fdtoverlay, fdtget, fdtput) and fdtdump are left in the
# main package. Meson installs "fdtdump" (upstream recipe typo: "ftdump").
# We fix dtc-misc and add dtc-tools so images get fdtoverlay and all utilities.
# Requires PACKAGECONFIG += "tools" (default in upstream).

# Fix upstream typo: meson builds fdtdump, not ftdump
FILES:${PN}-misc = "${bindir}/convert-dtsv0 ${bindir}/fdtdump ${bindir}/dtdiff"

PACKAGES:append = " ${PN}-tools"
FILES:${PN}-tools = " \
    ${bindir}/fdtoverlay \
    ${bindir}/fdtget \
    ${bindir}/fdtput \
"
# Optional: pull in main dtc when installing dtc-tools (e.g. for scripting)
# RDEPENDS:${PN}-tools += "${PN}"
