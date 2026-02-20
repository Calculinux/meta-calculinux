# meta-lts-mixins cargo recipe uses WORKDIR for snapshot path; in walnascar unpack
# goes to UNPACKDIR (default ${WORKDIR}/sources). Use UNPACKDIR and glob for
# install.sh like Poky's cargo/rust recipes.
do_cargo_setup_snapshot () {
	found=
	for installer in "${UNPACKDIR}/rust-snapshot-components/"cargo-*/install.sh; do
		[ -f "$installer" ] || continue
		sh "$installer" --prefix="${WORKDIR}/${CARGO_SNAPSHOT}" --disable-ldconfig
		found=1
		break
	done
	if [ -z "$found" ]; then
		echo "No cargo snapshot install.sh found under ${UNPACKDIR}/rust-snapshot-components/"
		ls -la "${UNPACKDIR}/rust-snapshot-components/" 2>/dev/null || true
		exit 1
	fi
	if [ -n "${UNINATIVE_LOADER}" ] && [ -e "${UNINATIVE_LOADER}" ]; then
		patchelf-uninative ${WORKDIR}/${CARGO_SNAPSHOT}/bin/cargo --set-interpreter ${UNINATIVE_LOADER}
	fi
}
