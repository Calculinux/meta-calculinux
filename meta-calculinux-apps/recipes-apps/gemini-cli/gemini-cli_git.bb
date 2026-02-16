HOMEPAGE = "https://github.com/reugn/gemini-cli"
SUMMARY = "Command-line interface for Google Gemini"
DESCRIPTION = "A CLI for interacting with Google Gemini generative models \
through multi-turn chat. Supports model selection, system prompts, and \
chat history management. Requires GEMINI_API_KEY environment variable."
SECTION = "console/utils"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=6104b260e1c764d0c6a341310c5f34c7"

inherit go-mod

SRC_URI = "\
    git://${GO_IMPORT};destsuffix=git/src/${GO_IMPORT};nobranch=1;name=${BPN};protocol=https \
"

SRCREV = "721548207f979c4ddcd016c7c8b6021970946b7c"

S = "${WORKDIR}/git"

GO_IMPORT = "github.com/reugn/gemini-cli"

# Install the gemini binary from cmd/gemini
GO_INSTALL = "${GO_IMPORT}/cmd/gemini"
