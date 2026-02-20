# meta-lts-mixins rust-cross-canadian.inc uses S = "${WORKDIR}" which is no longer
# allowed in walnascar. Override to use a subdir so the recipe parses and builds.
S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"
