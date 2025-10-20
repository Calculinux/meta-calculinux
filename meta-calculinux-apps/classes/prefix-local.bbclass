# Class to set the install prefix to /usr/local
prefix := "/usr/local"
exec_prefix := "${prefix}"
bindir := "${exec_prefix}/bin"
libdir := "${exec_prefix}/lib"

EXTRA_OECONF += "--prefix=${prefix}"
EXTRA_OECMAKE += "-DCMAKE_INSTALL_PREFIX=${prefix}"

# Update FILES to include /usr/local paths
python __anonymous () {
    for pkg in d.getVar('PACKAGES').split():
        files = d.getVar('FILES_' + pkg)
        if files:
            files += " ${prefix}/bin/* ${prefix}/lib/*"
            d.setVar('FILES_' + pkg, files)
}
