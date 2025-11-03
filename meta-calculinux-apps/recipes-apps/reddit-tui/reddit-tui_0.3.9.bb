HOMEPAGE = "https://github.com/tonymajestro/reddit-tui"
SUMMARY = "Terminal UI for reddit "
DESCRIPTION = "A lightweight terminal application for browsing Reddit \
from your command line. \
"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE.txt;md5=b023c325a5f9647a25b69a6615573986"

inherit go-mod

SRC_URI = "\
    git://${GO_IMPORT};destsuffix=git/src/${GO_IMPORT};nobranch=1;name=${BPN};protocol=https \
"

SRCREV = "3a594f6dce40fb9b301f5c26ab560aae6eebd47f"

S = "${WORKDIR}/git"

GO_IMPORT = "github.com/tonymajestro/reddit-tui"

do_install:append() {
    rm ${D}/usr/lib/go/src/github.com/tonymajestro/reddit-tui/install.sh
    rm ${D}/usr/lib/go/src/github.com/tonymajestro/reddit-tui/uninstall.sh
}
