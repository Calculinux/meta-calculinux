SUMMARY = "Meta Calculinux Apps package group"
DESCRIPTION = "Package group for additional applications and tools for Calculinux"

LICENSE = "MIT"

inherit packagegroup

# Disable GTK GUI and sound for vim so we don't pull in an entire desktop stack
PACKAGECONFIG:remove:pn-vim = "gtkgui sound"

PACKAGES = "${PN}"

# Add packages that should be available in the apps layer
# These will be built as IPKs and made available in the package feed
# Optional / large packages stay in this group so CI publishes IPKs to the
# feed (opkg install …) without putting them in calculinux-image.
RDEPENDS:${PN} = " \
    amfora \
    autoconf \
    automake \
    avahi-daemon \
    basilisk-ii \
    beetle-pce-fast-libretro \
    binutils \
    bison \
    bluez5 \
    bombadillo \
    cargo \
    circumflex \
    criu \
    diffutils \
    dosbox-pure-libretro \
    emacs-full \
    fceumm-libretro \
    file \
    flex \
    frodo-libretro \
    gambatte-libretro \
    gdb \
    gemini-cli \
    gettext \
    glkcli \
    glkterm \
    gpm \
    iotop \
    jq \
    kiwix-tools \
    libtool \
    lsof \
    m4 \
    mame2003-plus-libretro \
    mc \
    meshtastic-cli \
    meshtasticd \
    nano \
    nmap \
    nodejs \
    nodejs-npm \
    notcurses \
    notcurses-demos \
    nfs-utils \
    ntp \
    patch \
    patchelf \
    pcsx-rearmed-libretro \
    picoarch \
    picocalc-kbd-test \
    picodrive-libretro \
    python3 \
    python3-pip \
    python3-wik \
    reddit-tui \
    retro8-libretro \
    rpcbind \
    rsync \
    rust \
    screen \
    sdl2-test \
    snes9x-libretro \
    strace \
    sysstat \
    tcpdump \
    tic-80 \
    tmux \
    tree \
    uwific \
    valgrind \
    vice-libretro \
    vim \
    wiki-tui \
    x48ng \
    zerotier-one \
"
