SUMMARY = "Screenshot tool for DRM/KMS framebuffers"
DESCRIPTION = "A minimal single-file C utility that captures the active DRM/KMS \
scanout framebuffer (prime export + mmap) and saves it as a PNG. Gives the \
device a one-command screenshot (kmsgrab shot.png) without requiring the \
full FFmpeg stack for kmsgrab capture."
HOMEPAGE = "https://github.com/pcercuei/kmsgrab"
SECTION = "console/utils"

LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://kmsgrab.c;beginline=2;endline=5;md5=f65e1dabd703885e39545e6268ed0b58"

SRC_URI = "git://github.com/pcercuei/kmsgrab.git;protocol=https;branch=main"
# Upstream has no release tags; pin the last main commit (2023-12-21).
SRCREV = "d4c6061a59f4b7ecb6b39f96c7d39a5d5f48b702"

PV = "0.1+git${SRCPV}"

S = "${WORKDIR}/git"

inherit cmake pkgconfig

DEPENDS = "libdrm libpng"
