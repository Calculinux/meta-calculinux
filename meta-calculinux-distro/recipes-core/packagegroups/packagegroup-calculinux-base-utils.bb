SUMMARY = "Calculinux base utilities (replaces busybox)"
DESCRIPTION = "Full GNU/util-linux style userland in place of busybox. \
Selected through VIRTUAL-RUNTIME_base-utils, so packagegroup-core-boot \
pulls this in instead of busybox. Like oe-core's \
packagegroup-core-base-utils, but without dhcpcd (iwd and networkd do \
DHCP), parted, ifupdown or the inetutils servers/clients."
LICENSE = "MIT"

inherit packagegroup

# Tools that the image already installs on its own (bash, grep, sed,
# findutils, diffutils, gzip, less, util-linux, shadow, iproute2, kmod,
# which, wget, file, unzip, e2fsprogs) are not repeated here.
RDEPENDS:${PN} = "\
    attr \
    bc \
    bind-utils \
    bzip2 \
    coreutils \
    cpio \
    dash \
    fbset \
    gawk \
    inetutils-hostname \
    iputils-ping \
    ncurses-tools \
    netcat-openbsd \
    patch \
    picocom \
    procps \
    psmisc \
    tar \
    time \
    traceroute \
    vim \
    xz \
"
