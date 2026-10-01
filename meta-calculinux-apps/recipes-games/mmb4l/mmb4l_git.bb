SUMMARY = "MMBasic for Linux (MMB4L)"
DESCRIPTION = "MMB4L is a port of Geoff Graham's MMBasic BASIC interpreter to \
the Linux platform (and its derivatives). It provides an interactive BASIC \
shell with a built-in or external editor, file I/O and SDL2-backed graphics \
and audio, and can simulate several other MMBasic devices (e.g. PicoMite/VGA, \
Colour Maximite 2, MMBasic for Windows)."
HOMEPAGE = "https://github.com/thwill1000/mmb4l"
SECTION = "games"

# MMB4L as a whole is licensed under a modified 4-clause BSD license
# (see LICENSE.MMBasic); individual pieces (mostly unit tests and utility
# code) are dual-licensed under the MIT license (see LICENSE.MIT).
LICENSE = "BSD-4-Clause & MIT"
LIC_FILES_CHKSUM = "file://LICENSE.MMBasic;md5=c0ad0b6f0d9d01ea45125a1821518deb; \
                    file://LICENSE.MIT;md5=dea4775429a48bf414110618f116c657"

# v0.8-alpha.1 tag; the numeric version encoding is documented in MM.INFO(VERSION)
PV = "0.8.0_alpha1"

SRC_URI = "git://github.com/thwill1000/mmb4l.git;protocol=https;tag=v0.8-alpha.1 \
           file://0001-CMake-Allow-disabling-unit-tests.patch \
           file://0002-CMake-Do-not-treat-warnings-as-errors.patch \
           "
SRCREV = "8e98d84627c49fe95e5d3fb958080ac6cbd02d88"
S = "${WORKDIR}/git"

# The "sptools" submodule is only used by upstream's integration tests,
# which this package does not build, so it is intentionally not fetched.

inherit cmake pkgconfig

DEPENDS = "libsdl2"

# The upstream build always fetches GoogleTest via CMake FetchContent at
# configure time and builds ~30 unit-test executables. This package only
# needs the mmbasic executable and network access during configure is not
# acceptable, so disable the tests (default remains ON for upstream users).
EXTRA_OECMAKE = "-DMMB4L_BUILD_TESTS=OFF"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/mmbasic ${D}${bindir}/mmbasic

    install -d ${D}${docdir}/mmb4l
    install -m 0644 ${S}/ChangeLog ${D}${docdir}/mmb4l/
}

FILES:${PN} = "${bindir}/mmbasic"
FILES:${PN}-doc = "${docdir}/mmb4l/*"

COMPATIBLE_MACHINE = "luckfox-lyra"
