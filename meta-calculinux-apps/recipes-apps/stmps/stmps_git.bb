HOMEPAGE = "https://github.com/spezifisch/stmps"
SUMMARY = "A terminal music player for Subsonic-compatible servers"
DESCRIPTION = "stmps (Subsonic Terminal Music Player S) is a TUI client for \
Subsonic API servers such as Navidrome, Airsonic and Gonic. It browses and \
queues music from the server and plays it through libmpv. \
"

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

inherit go-mod

# go-mpv binds libmpv through cgo (pkg-config: mpv)
DEPENDS += "mpv"
RDEPENDS:${PN} += "mpv"

SRC_URI = "\
    git://${GO_IMPORT};destsuffix=git/src/${GO_IMPORT};nobranch=1;name=${BPN};protocol=https \
"

SRCREV = "4a8428bc06cc2490ff1caf7fc53fcacc5fc398c0"

S = "${WORKDIR}/git"

# Go modules are fetched by the go tool during compile; bitbake isolates
# tasks from the network unless they opt in.
do_compile[network] = "1"

GO_IMPORT = "github.com/spezifisch/stmps"
