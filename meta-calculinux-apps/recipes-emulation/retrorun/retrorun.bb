# Recipe created by recipetool
# This is the basis of a recipe and may need further editing in order to be fully functional.
# (Feel free to remove these comments when editing.)

# WARNING: the following LICENSE and LIC_FILES_CHKSUM values are best guesses - it is
# your responsibility to verify that the values are complete and correct.
#
# The following license files were not able to be identified and are
# represented as "Unknown" below, you will need to check them yourself:
#   LICENSE
#   deps/libchdr/LICENSE.txt
#   deps/libchdr/deps/lzma-25.01/LICENSE
#   deps/minizip/LICENSE
#
# NOTE: multiple licenses have been detected; they have been separated with &
# in the LICENSE value for now since it is a reasonable assumption that all
# of the licenses apply. If instead there is a choice between the multiple
# licenses then you should change the value to separate the licenses with |
# instead of &. If there is any doubt, check the accompanying documentation
# to determine which situation is applicable.
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=3cb79dafc1fb222af3f1c5e010bdc39a"

SRC_URI = "gitsm://github.com/gurubook/retrorun;protocol=https;branch=picocalc"

# Modify these as desired
PV = "1.0+git"
SRCREV = "1f9322d4f12094db3439cf94c2ce581d9f02a299"

S = "${WORKDIR}/git"

DEPENDS = " \
	pkgconfig \
    libsdl2 \
    libpng \
	curl \
"

inherit pkgconfig

# NOTE: this is a Makefile-only piece of software, so we cannot generate much of the
# recipe automatically - you will need to examine the Makefile yourself and ensure
# that the appropriate arguments are passed in.

do_configure () {
	# Specify any needed configure commands here
	:
}

do_compile () {
	# You will almost certainly need to add additional arguments here
	oe_runmake linux-sdl2-picocalc config=release
}

do_install () {
	# NOTE: unable to determine what to put here - there is a Makefile but no
	# target named "install", so you will need to define this yourself
    install -d ${D}${bindir}
	install -m 0755 ${S}/retrorun-sdl2-picocalc ${D}${bindir}/
}

FILES:${PN} = "${bindir}/retrorun-sdl2-picocalc"

# alsa-lib is not linked by the binary: this SDL build uses
# SDL_ALSA_SHARED, so the audio backend is loaded dynamically by SDL and
# shlibdeps cannot see it (the launcher also forces SDL_AUDIODRIVER=alsa
# and picoarch quits if audio init fails).
RDEPENDS:${PN} = " \
    libpng \
    alsa-lib \
    libsdl2 \
"

# The upstream Makefile strips the binary with -s, so skip this QA check
INSANE_SKIP:${PN} += "already-stripped"