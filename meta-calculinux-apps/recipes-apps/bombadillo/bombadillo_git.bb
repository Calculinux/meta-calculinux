HOMEPAGE = "https://bombadillo.colorfield.space"
SUMMARY = "Non-web terminal client for Gopher, Gemini and more"
DESCRIPTION = "Bombadillo is a non-web client for the terminal supporting \
Gopher, Gemini, Finger, and local file systems. Also supports Telnet and \
HTTP/HTTPS via external applications. Vim-like keybindings, bookmarking, \
and configurable settings."
SECTION = "console/network"

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=ff3103b5db8ba4e2c66c511b7a73e407"

inherit go-mod

# Tildegit requires HTTPS
SRC_URI = "\
    git://${GO_IMPORT};destsuffix=git/src/${GO_IMPORT};nobranch=1;name=${BPN};protocol=https \
"

SRCREV = "b171dc2230fcd2dec5cf5ab9d461f2470d799bbe"

S = "${WORKDIR}/git"

GO_IMPORT = "tildegit.org/sloum/bombadillo"
