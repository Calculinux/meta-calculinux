SUMMARY = "Meta Calculinux Apps package group"
DESCRIPTION = "Package group for additional applications and tools for Calculinux"

LICENSE = "MIT"

inherit packagegroup

# Disable GTK GUI and sound for vim so we don't pull in an entire desktop stack
PACKAGECONFIG:remove:pn-vim = "gtkgui sound"

PACKAGES = "${PN}"

# Add packages that should be available in the apps layer
# These will be built as IPKs and made available in the package feed
RDEPENDS:${PN} = " \
    android-adbd \
    cargo \
    circumflex \
    glkcli \
    glkterm \
    iotop \
    jq \
    kiwix-tools \
    lsof \
    mc \
    nano \
    nmap \
    nodejs \
    nodejs-npm \
    python3 \
    python3-pip \
    reddit-tui \
    rsync \
    rust \
    screen \
    sysstat \
    tcpdump \
    tmux \
    tree \
    vim \
    x48ng \
    zerotier-one \
"
