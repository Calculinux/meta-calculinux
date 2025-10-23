FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add GPM (General Purpose Mouse) support for console mouse handling
#DEPENDS += "gpm"

# Override to use ABI version 6 to enable extended color functions
# This provides init_extended_pair, alloc_pair, and free_pair functions
# and is source compatible with the v5 ABI, so as long as we are compiling
# against this library there should be no compatibility issues.

EXTRA_OECONF += "--with-abi-version=6"

# Enable GPM support (overrides --without-gpm from base recipe)
EXTRA_OECONF += "--with-gpm"

# Skip QA checks that are triggered by our compatibility layer
# dev-deps: libraries reference the linker script which is in -dev
# dev-elf: linker scripts look like .so files but aren't ELF binaries
INSANE_SKIP:${PN} += "dev-deps"
INSANE_SKIP:${PN}-dev += "dev-elf"
INSANE_SKIP:${PN}-libncursesw += "dev-deps"
INSANE_SKIP:${PN}-libmenuw += "dev-deps"
INSANE_SKIP:${PN}-libformw += "dev-deps"
INSANE_SKIP:${PN}-libpanelw += "dev-deps"
INSANE_SKIP:${PN}-libticw += "dev-deps"
INSANE_SKIP:${PN}-tools += "dev-deps"

# Fix the linker scripts to reference the correct version AND provide compatibility symlinks
do_install:append() {
    # Fix wide-character library linker scripts to reference .so.6 instead of .so.5
    for lib in libncursesw libpanelw libmenuw libformw libtinfo; do
        if [ -f ${D}${libdir}/${lib}.so ]; then
            sed -i 's/\.so\.5/.so.6/g' ${D}${libdir}/${lib}.so
        fi
        
        # Create .so.5 -> .so.6 compatibility symlinks for packages that expect v5
        # Find the actual .so.6.X file and create symlink
        sofile=$(ls ${D}${libdir}/${lib}.so.6* 2>/dev/null | head -n1)
        if [ -n "$sofile" ]; then
            ln -sf $(basename $sofile) ${D}${libdir}/${lib}.so.5
        fi
    done
    
    # Create linker scripts (not symlinks) for non-wide libraries that reference both
    # the wide version AND libtinfo (which contains terminal capability symbols like UP, BC, PC)
    # This ensures programs linking against libncurses get all the symbols they need
    
    # libncurses.so linker script pointing to both libncursesw and libtinfo
    cat > ${D}${libdir}/libncurses.so << 'EOF'
/* GNU ld script */
GROUP ( libncursesw.so.6 libtinfo.so.6 )
EOF
    
    # Create versioned symlinks for libncurses
    ln -sf libncursesw.so.6.5 ${D}${libdir}/libncurses.so.6.5
    ln -sf libncursesw.so.6 ${D}${libdir}/libncurses.so.6
    ln -sf libncursesw.so.5 ${D}${libdir}/libncurses.so.5
    
    # For other libraries, simple symlinks to wide versions are sufficient
    ln -sf libpanelw.so.6.5 ${D}${libdir}/libpanel.so.6.5
    ln -sf libpanelw.so.6 ${D}${libdir}/libpanel.so.6
    ln -sf libpanelw.so.5 ${D}${libdir}/libpanel.so.5
    ln -sf libpanel.so.6 ${D}${libdir}/libpanel.so
    
    ln -sf libmenuw.so.6.5 ${D}${libdir}/libmenu.so.6.5
    ln -sf libmenuw.so.6 ${D}${libdir}/libmenu.so.6
    ln -sf libmenuw.so.5 ${D}${libdir}/libmenu.so.5
    ln -sf libmenu.so.6 ${D}${libdir}/libmenu.so
    
    ln -sf libformw.so.6.5 ${D}${libdir}/libform.so.6.5
    ln -sf libformw.so.6 ${D}${libdir}/libform.so.6
    ln -sf libformw.so.5 ${D}${libdir}/libform.so.5
    ln -sf libform.so.6 ${D}${libdir}/libform.so
    
    # Create pkg-config compatibility files for non-wide library names
    # This allows packages that look for "ncurses" to find "ncursesw"
    if [ -d ${D}${libdir}/pkgconfig ]; then
        cd ${D}${libdir}/pkgconfig
        
        # Create ncurses.pc that references ncursesw and tinfo
        ln -sf ncursesw.pc ncurses.pc
        ln -sf panelw.pc panel.pc
        ln -sf menuw.pc menu.pc
        ln -sf formw.pc form.pc
        
        # Also create ncurses++.pc -> ncurses++w.pc
        if [ -f ncurses++w.pc ]; then
            ln -sf ncurses++w.pc ncurses++.pc
        fi
        
        # Create tic.pc -> ticw.pc
        if [ -f ticw.pc ]; then
            ln -sf ticw.pc tic.pc
        fi
    fi
}