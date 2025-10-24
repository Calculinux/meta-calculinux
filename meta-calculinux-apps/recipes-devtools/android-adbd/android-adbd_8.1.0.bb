SUMMARY = "Android Debug Bridge daemon"
DESCRIPTION = "Android Debug Bridge (ADB) daemon for Android debugging and development. \
Provides remote shell access and debugging capabilities."
HOMEPAGE = "https://developer.android.com/studio/command-line/adb"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://debian/copyright;md5=f6d5f92d58d34638365ec9c5fe15d13d"

MY_PV = "8.1.0+r23-8"
MY_FULL_PV = "1%25${MY_PV}"
MY_P_ENCODED = "android-platform-system-core-debian-${MY_FULL_PV}"
MY_P_DECODED = "android-platform-system-core-debian-1%${MY_PV}"

SRC_URI = "\
    https://salsa.debian.org/android-tools-team/android-platform-system-core/-/archive/debian/${MY_FULL_PV}/${MY_P_ENCODED}.tar.gz \
    file://0001-adb-libcrypto_utils-Switch-to-libopenssl.patch \
    file://0002-adb-daemon-Support-linux.patch \
    file://0003-adb-daemon-Support-custom-auth-command.patch \
    file://0004-adb-Use-login-shell.patch \
    file://0005-adb-Support-setting-adb-shell.patch \
    file://0006-adb-daemon-Fix-build-issue-with-old-g.patch \
    file://0007-adb-daemon-Handle-SIGINT.patch \
    file://0008-adb-daemon-Fix-build-issue-with-musl-and-uclibc.patch \
    file://0009-adb-daemon-Fix-cpp-version-header-issue.patch \
    file://0011-adb-daemon-fix-openssl3-rsa-deprecation.patch \
    file://0012-adb-daemon-fix-typeof-cpp17.patch \
    file://adbd.service \
    file://adbd-auth \
"

SRC_URI[sha256sum] = "74689eaf472763aa7f842eb277cb62fbe08ebcabc7687f4546cec2383838435e"

S = "${WORKDIR}/${MY_P_DECODED}"

DEPENDS = "openssl"

inherit meson pkgconfig systemd

# Simple PACKAGECONFIG - just for static builds
PACKAGECONFIG ??= ""
PACKAGECONFIG[static] = "-Ddefault_library=static,-Ddefault_library=shared"

EXTRA_OEMESON = ""

# Apply Debian patches before our Buildroot patches
# Yocto will automatically apply our patches from files/ after this
do_patch[prefuncs] += "apply_debian_patches"

python apply_debian_patches() {
    import subprocess
    import os
    
    s_dir = d.getVar('S')
    debian_patches_dir = os.path.join(s_dir, 'debian', 'patches')
    
    if not os.path.exists(debian_patches_dir):
        return
    
    # Read series file for patch order
    series_file = os.path.join(debian_patches_dir, 'series')
    if os.path.exists(series_file):
        with open(series_file, 'r') as f:
            patches = [line.strip() for line in f if line.strip() and not line.startswith('#')]
    else:
        patches = sorted([f for f in os.listdir(debian_patches_dir) if f.endswith('.patch')])
    
    # Apply each patch
    for patch in patches:
        patch_path = os.path.join(debian_patches_dir, patch)
        if os.path.exists(patch_path):
            bb.note("Applying Debian patch: %s" % patch)
            subprocess.run(['patch', '-p1', '-i', patch_path], 
                          cwd=s_dir, check=True)
}

do_install:append() {
    # Install systemd service file
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/sources-unpack/adbd.service ${D}${systemd_system_unitdir}/adbd.service
    
    # Install shell profile script
    install -d ${D}${sysconfdir}/profile.d
    echo '[ -x /bin/bash ] && export ADBD_SHELL=/bin/bash' > ${D}${sysconfdir}/profile.d/adbd.sh
    
    # Create ADB keys directory
    install -d ${D}/data/misc/adb
}

SYSTEMD_SERVICE:${PN} = "adbd.service"
SYSTEMD_AUTO_ENABLE = "enable"

FILES:${PN} += "\
    ${sysconfdir}/profile.d/adbd.sh \
    /data/misc/adb \
"

RDEPENDS:${PN} = "openssl bash"
