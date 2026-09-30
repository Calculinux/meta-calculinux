# Make dash /bin/sh. bash registers sh at priority 100 and dash only at 10,
# so without this bash would keep winning while both are installed.
# Interactive users (root, pico) get bash as their login shell instead.
ALTERNATIVE_PRIORITY = "200"
