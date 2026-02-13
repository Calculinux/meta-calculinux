SUMMARY = "Command-line tool to view Wikipedia pages from the terminal"
DESCRIPTION = "WIK is a command-line tool to view Wikipedia pages from your \
terminal. It lets you search Wikipedia articles with a single query. Supports \
caching for offline access, multiple languages, and quick summaries."
HOMEPAGE = "https://github.com/yashsinghcodes/wik"
SECTION = "console/utils"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=8da2e9527e5472276c35b9ca6e1a7f2e"

PYPI_PACKAGE = "wik"

inherit pypi python_flit_core

RDEPENDS:${PN} += " \
    python3-beautifulsoup4 \
    python3-requests \
"
