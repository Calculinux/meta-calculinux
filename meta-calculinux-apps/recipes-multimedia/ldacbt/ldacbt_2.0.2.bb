SUMMARY = "LDAC Bluetooth codec libraries (encoder and ABR helper)"
DESCRIPTION = "LDAC (Lossless over Digital Audio Codec) for Bluetooth, as \
shipped by the AOSP libldac project: libldacBT_enc (the encoder) and \
libldacBT_abr (the adaptive-bit-rate helper), exposing the ldacBT-enc and \
ldacBT-abr pkg-config modules. The public release includes the encoder only, \
so consumers (e.g. bluez-alsa) act as LDAC source only."
HOMEPAGE = "https://github.com/EHfive/ldacBT"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

# The git repository and its tags do not carry the AOSP libldac sources
# (libldac/ is only populated in the release tarball, which GitHub Actions
# bundles at release time); build from the release archive instead. The
# pkg-config modules advertise 2.0.2.3 regardless of the tarball release.
SRC_URI = "https://github.com/EHfive/ldacBT/releases/download/v2.0.2.6/ldacBT-2.0.2.6.tar.gz"
SRC_URI[sha256sum] = "fee05740e86ee66f4540486d92683ee8e8071119907b57ca762c7e5d943ecef0"

# The archive has no single root directory, so it unpacks flat into
# UNPACKDIR; point S there (the pattern recommended by the YP 5.1 migration
# guide for rootless archives).
S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

inherit cmake

# The project's CMake takes its install directories from INSTALL_* variables
# (not CMAKE_INSTALL_*), so point them at the OE layout explicitly.
EXTRA_OECMAKE = " \
    -DINSTALL_LIBDIR=${libdir} \
    -DINSTALL_INCLUDEDIR=${includedir} \
    -DINSTALL_PKGCONFIGDIR=${libdir}/pkgconfig \
    -DINSTALL_LDAC_INCLUDEDIR=${includedir}/ldac \
"

# Float-point math (default): the target has an FPU. Leave LDAC_SOFT_FLOAT
# off unless a soft-float target ever joins the fleet.

FILES:${PN} = "${libdir}/libldacBT_*.so.*"
FILES:${PN}-dev = " \
    ${includedir}/ldac \
    ${libdir}/libldacBT_*.so \
    ${libdir}/pkgconfig \
"
