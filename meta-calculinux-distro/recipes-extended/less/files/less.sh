#!/bin/sh
# Configure less for UTF-8 support

# Tell less to use UTF-8 character encoding
export LESSCHARSET=utf-8

# Additional less options:
# -R: Display ANSI color escape sequences in "raw" form
# -F: Quit if entire file fits on first screen
# -X: Don't clear screen on exit
export LESS="-R -F -X"
