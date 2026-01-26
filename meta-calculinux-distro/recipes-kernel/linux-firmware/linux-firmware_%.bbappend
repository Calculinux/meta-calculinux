# Prevent the main linux-firmware metapackage from pulling in ALL 315 firmware packages.
# The base recipe adds RRECOMMENDS for all split packages to the main package via:
#   d.appendVar('RRECOMMENDS:linux-firmware', ' ' + ' '.join(firmware_pkgs))
# This causes opkg to install everything (1GB+). We want ONLY specific WiFi firmware
# packages that are explicitly listed in our image recipe (defined in kas config).
#
# Additionally, individual split packages have RDEPENDS on the main linux-firmware package
# (visible in package metadata but not explicitly set in recipe - may be auto-generated).
# We need to remove this dependency to allow installing individual packages standalone.

python populate_packages:append () {
    # Clear the RRECOMMENDS that the original recipe added to the main package
    d.setVar('RRECOMMENDS:linux-firmware', '')
    
    # Remove RDEPENDS on main package from all split packages
    packages = d.getVar('PACKAGES').split()
    for pkg in packages:
        if pkg.startswith('linux-firmware-') and pkg != 'linux-firmware':
            rdeps = d.getVar('RDEPENDS:%s' % pkg) or ''
            if rdeps:
                rdeps_list = rdeps.split()
                # Remove main package but keep license dependencies
                if 'linux-firmware' in rdeps_list:
                    rdeps_list.remove('linux-firmware')
                    d.setVar('RDEPENDS:%s' % pkg, ' '.join(rdeps_list))
}

# Allow the main metapackage to be empty since we're not using it
ALLOW_EMPTY:${PN} = "1"
