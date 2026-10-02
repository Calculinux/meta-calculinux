SUMMARY = "Calculinux emulator launcher"
DESCRIPTION = "The window the calculinux-emulator AppImage opens before booting: \
lists the published system images, downloads the chosen one and deletes old \
ones. Also does the emulator's headless image downloads. Dear ImGui on SDL2's \
software renderer, plus libcurl."
HOMEPAGE = "https://github.com/Calculinux/calculinux-emulator-launcher"
LICENSE = "MIT"
# The launcher, and the Dear ImGui and nlohmann/json sources it vendors.
LIC_FILES_CHKSUM = " \
    file://LICENSE;md5=0c1ca00017fe02adea99b8b709ff179b \
    file://third_party/imgui/LICENSE.txt;md5=b8cd90c48092bf3bc38d9fc3dcf35180 \
    file://third_party/nlohmann/LICENSE.MIT;md5=3b489645de9825cca5beeb9a7e18b6eb \
"

SRC_URI = "git://github.com/Calculinux/calculinux-emulator-launcher.git;protocol=https;branch=main"
SRCREV = "b034f954f7aba9c6ba7a585bfce758e801ff9b15"
PV = "0.1.0+git"

S = "${WORKDIR}/git"

DEPENDS = "libsdl2 curl"

inherit cmake pkgconfig

# The tests need a display-less SDL and a local web server; the launcher
# repository's own CI runs them.
EXTRA_OECMAKE = "-DLAUNCHER_BUILD_TESTS=OFF"

# Only built for the emulator AppImage (nativesdk).
EXCLUDE_FROM_WORLD = "1"
BBCLASSEXTEND = "nativesdk"
