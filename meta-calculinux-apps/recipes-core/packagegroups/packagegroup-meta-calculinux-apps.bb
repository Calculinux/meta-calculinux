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
    autoconf \
    automake \
    basilisk-ii \
    beetle-pce-fast-libretro \
    binutils \
    bison \
    cargo \
    circumflex \
    diffutils \
    dosbox-pure-libretro \
    emacs-full \
    fceumm-libretro \
    fd-find \
    file \
    flex \
    frodo-libretro \
    fzf \
    gambatte-libretro \
    gdb \
    gettext \
    glkcli \
    glkterm \
    hoard-of-bitfonts-acorn \
    hoard-of-bitfonts-amiga \
    hoard-of-bitfonts-amstrad \
    hoard-of-bitfonts-apple \
    hoard-of-bitfonts-atari \
    hoard-of-bitfonts-banner \
    hoard-of-bitfonts-commodore \
    hoard-of-bitfonts-crt8002 \
    hoard-of-bitfonts-custom \
    hoard-of-bitfonts-datapoint \
    hoard-of-bitfonts-dec \
    hoard-of-bitfonts-elan-enterprise \
    hoard-of-bitfonts-elektronika \
    hoard-of-bitfonts-epson \
    hoard-of-bitfonts-fujitsu \
    hoard-of-bitfonts-gem \
    hoard-of-bitfonts-geos \
    hoard-of-bitfonts-hellschreiber \
    hoard-of-bitfonts-hp \
    hoard-of-bitfonts-jupiter-cantab \
    hoard-of-bitfonts-kyotronic \
    hoard-of-bitfonts-msx \
    hoard-of-bitfonts-ncr7250 \
    hoard-of-bitfonts-nec-pc \
    hoard-of-bitfonts-next \
    hoard-of-bitfonts-oric \
    hoard-of-bitfonts-os2 \
    hoard-of-bitfonts-palm \
    hoard-of-bitfonts-pc \
    hoard-of-bitfonts-pc-geos \
    hoard-of-bitfonts-rk86 \
    hoard-of-bitfonts-robotron \
    hoard-of-bitfonts-sharp \
    hoard-of-bitfonts-sinclair \
    hoard-of-bitfonts-teletext \
    hoard-of-bitfonts-texas-instruments \
    hoard-of-bitfonts-trs80 \
    hoard-of-bitfonts-various \
    hoard-of-bitfonts-videoton-tvc \
    hoard-of-bitfonts-windows \
    hoard-of-bitfonts-xerox \
    iotop \
    jq \
    kiwix-tools \
    libtool \
    lsof \
    m4 \
    mame2003-plus-libretro \
    mc \
    meshtasticd \
    nano \
    nmap \
    nodejs \
    nodejs-npm \
    notcurses \
    notcurses-demos \
    oldschool-console-fonts \
    patch \
    pcsx-rearmed-libretro \
    picoarch \
    picodrive-libretro \
    python3 \
    python3-pip \
    reddit-tui \
    retro8-libretro \
    ripgrep \
    rsync \
    rust \
    screen \
    sdl2-test \
    snes9x-libretro \
    strace \
    sysstat \
    tcpdump \
    terminus-font \
    tmux \
    tree \
    valgrind \
    vice-libretro \
    vim \
    x48ng \
    zerotier-one \
"
