SUMMARY = "Notcurses: blingful TUIs and character graphics"
DESCRIPTION = "Notcurses facilitates the creation of modern TUI programs, \
making it easy to use features of modern terminals: 24-bit color, italics, \
transparency, UTF-8, and high-resolution bitmap graphics."
HOMEPAGE = "https://github.com/dankamongmen/notcurses"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://COPYRIGHT;md5=9d4fc1f864192e96250fc5464c06737e"

DEPENDS = "ncurses zlib libdeflate libunistring"

SRC_URI = "git://github.com/dankamongmen/notcurses.git;protocol=https;branch=master;tag=v3.0.17"

S = "${WORKDIR}/git"

inherit cmake pkgconfig

EXTRA_OECMAKE = " \
    -DUSE_MULTIMEDIA=none \
    -DUSE_DEFLATE=ON \
    -DBUILD_TESTING=OFF \
    -DUSE_DOCTEST=OFF \
    -DUSE_PANDOC=OFF \
"

# Split packages for demos and tools
PACKAGES =+ "${PN}-demos ${PN}-tools"

FILES:${PN} = "${libdir}/libnotcurses*.so.* ${libdir}/libnotcurses-core*.so.*"
FILES:${PN}-dev = "${includedir} ${libdir}/pkgconfig ${libdir}/*.so ${libdir}/cmake"
FILES:${PN}-demos = "${bindir}/notcurses-demo ${bindir}/notcurses-input ${datadir}/notcurses"
FILES:${PN}-tools = "${bindir}/ncls ${bindir}/ncneofetch ${bindir}/ncplayer ${bindir}/nctetris ${bindir}/notcurses-info ${bindir}/tfman"

RDEPENDS:${PN}-demos = "${PN}"
RDEPENDS:${PN}-tools = "${PN}"

# notcurses-demo is the main Unicode and graphics test application
RDEPENDS:${PN} = "ncurses libdeflate libunistring"
