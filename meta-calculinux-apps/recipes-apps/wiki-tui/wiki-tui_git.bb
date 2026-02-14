SUMMARY = "A simple and easy to use Wikipedia Text User Interface"
DESCRIPTION = "wiki-tui is a TUI client for browsing Wikipedia from the \
terminal. Features rich search results, table of contents, vim-like \
keybindings, multi-language support, and customizable themes."
HOMEPAGE = "https://wiki-tui.net"
SECTION = "console/utils"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0d4b70885d03e5f949ce9030bac50c5d"

SRC_URI = "git://github.com/Builditluc/wiki-tui.git;protocol=https;branch=main"
SRCREV = "ff41c522ae89627ea4ba7e0d630ea7cae9d3374b"

S = "${WORKDIR}/git"

PV = "0.9.2+git${SRCPV}"

inherit cargo

# Run 'bitbake -c update_crates wiki-tui' to generate wiki-tui-crates.inc
# for reproducible offline builds, then add: inherit cargo-update-recipe-crates
# and: require ${BPN}-crates.inc
