SUMMARY = "Meta Calculinux Apps package group"
DESCRIPTION = "Package group for additional applications and tools for Calculinux"

PACKAGES = "${PN}"

# Add packages that should be available in the apps layer
# These will be built as IPKs and made available in the package feed
RDEPENDS:${PN} = " \
    zerotier-one \
    vim \
    nano \
    mc \
    iotop \
    nmap \
    tcpdump \
    sysstat \
    lsof \
    tree \
    rsync \
    jq \
    tmux \
    screen \
"

inherit packagegroup

# This Python function applies the `prefix-local` class to every package
# in the RDEPENDS list, including its dependencies.
python do_apply_prefix_local() {
    # Get the list of packages specified in RDEPENDS
    rdepends_list = d.getVar('RDEPENDS').split()

    # Iterate over each package and apply the class
    for pkg in rdepends_list:
        # Check if the package recipe exists before applying the class
        if bb.utils.find_bbclass("prefix-local"):
            # This is the key part: inherit the custom class for each recipe
            bb.parse.inherit_recipe_class(d, pkg, "prefix-local")
}

addtask do_apply_prefix_local before do_build