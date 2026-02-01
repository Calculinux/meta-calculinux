HOMEPAGE = "https://github.com/bensadeh/circumflex"
SUMMARY = "It's Hacker News in your terminal"
DESCRIPTION = "circumflex is a command line tool for browsing \
Hacker News in your terminal \
"

LICENSE = "AGPL-3.0-only"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=4ae09d45eac4aa08d013b5f2e01c67f6"

inherit go-mod

SRC_URI = "\
    git://${GO_IMPORT};destsuffix=git/src/${GO_IMPORT};nobranch=1;name=${BPN};protocol=https \
"

SRCREV = "d3718631d4dad87c239d2d7b0209773dfdb40ea6"

S = "${WORKDIR}/git"

GO_IMPORT = "github.com/bensadeh/circumflex"
