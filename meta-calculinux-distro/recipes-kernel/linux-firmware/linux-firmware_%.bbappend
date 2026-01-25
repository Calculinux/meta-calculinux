# Remove dependency on main linux-firmware metapackage
# The metapackage pulls in ALL firmware (1GB+), but we only want specific WiFi firmware
# This allows individual firmware packages to be installed without the metapackage

# The populate_packages function in the base recipe adds the main package to RDEPENDS
# We need to remove that after the base recipe runs
python populate_packages:append () {
    # Get all packages created by this recipe
    packages = d.getVar('PACKAGES').split()
    
    # For each split package, remove the main linux-firmware from RDEPENDS
    for pkg in packages:
        if pkg.startswith('linux-firmware-') and pkg != 'linux-firmware':
            rdepends = d.getVar('RDEPENDS:%s' % pkg) or ''
            # Remove 'linux-firmware' but keep license packages
            rdepends_list = rdepends.split()
            if 'linux-firmware' in rdepends_list:
                rdepends_list.remove('linux-firmware')
                d.setVar('RDEPENDS:%s' % pkg, ' '.join(rdepends_list))
}

# Also need to prevent the main package from depending on all split packages
# This is done via the populate_packages function in the base recipe
# We override to make the main package optional
ALLOW_EMPTY:${PN} = "1"
