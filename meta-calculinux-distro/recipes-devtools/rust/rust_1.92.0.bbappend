# meta-lts-mixins rust recipe uses WORKDIR for snapshot path; in walnascar unpack
# goes to UNPACKDIR (default ${WORKDIR}/sources). Use UNPACKDIR like Poky's rust recipe.
do_rust_setup_snapshot () {
    for installer in "${UNPACKDIR}/rust-snapshot-components/"*"/install.sh"; do
        "${installer}" --prefix="${WORKDIR}/rust-snapshot" --disable-ldconfig
    done

    # Some versions of rust (e.g. 1.18.0) tries to find cargo in stage0/bin/cargo
    # and fail without it there.
    mkdir -p ${RUSTSRC}/build/${RUST_BUILD_SYS}
    ln -sf ${WORKDIR}/rust-snapshot/ ${RUSTSRC}/build/${RUST_BUILD_SYS}/stage0

    # Need to use uninative's loader if enabled/present since the library paths
    # are used internally by rust and result in symbol mismatches if we don't
    if [ ! -z "${UNINATIVE_LOADER}" ] && [ -e "${UNINATIVE_LOADER}" ]; then
        for bin in cargo rustc rustdoc; do
            patchelf ${WORKDIR}/rust-snapshot/bin/$bin --set-interpreter ${UNINATIVE_LOADER}
        done
    fi
}
