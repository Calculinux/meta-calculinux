SUMMARY = "Meta Calculinux Apps package group"
DESCRIPTION = "Package group for additional applications and tools for Calculinux"

inherit packagegroup

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
