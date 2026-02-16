HOMEPAGE = "https://github.com/makew0rld/amfora"
SUMMARY = "A terminal browser for the Gemini protocol"
DESCRIPTION = "Amfora is a beautiful terminal browser for the Gemini protocol. \
It aims to be the best-looking Gemini client with the most features while \
remaining fully functional in the terminal. \
"

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

inherit go-mod

# Clone into path matching go.mod module (github.com/makeworld-the-better-one/amfora)
SRC_URI = "\
    git://github.com/makew0rld/amfora;destsuffix=git/src/github.com/makeworld-the-better-one/amfora;nobranch=1;name=${BPN};protocol=https \
"

SRCREV = "4d9a5c56c88f7bec2938968182c88130b923fbba"

S = "${WORKDIR}/git"

# go.mod declares module github.com/makeworld-the-better-one/amfora
GO_IMPORT = "github.com/makeworld-the-better-one/amfora"
