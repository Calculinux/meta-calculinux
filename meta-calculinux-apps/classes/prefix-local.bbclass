# Set the desired installation prefix.
# Immediate expansion (:=) is important here to ensure the value is set early.
prefix := "/usr/local"
exec_prefix := "${prefix}"

# Add the new prefix to the Autotools configuration options.
EXTRA_OECONF += "--prefix=${prefix}"

# Add the new prefix to the CMake configuration options.
EXTRA_OECMAKE += "-DCMAKE_INSTALL_PREFIX=${prefix}"

# Update the FILES variable to ensure packages include the new path.
# This prevents Bitbake from complaining about files not being packaged.
# We must iterate over all subpackages to apply the new path.
python __anonymous () {
    for pkg in d.getVar('PACKAGES').split():
        files = d.getVar('FILES_' + pkg)
        if files:
            files += " ${prefix}/bin/* ${prefix}/lib/*"
            d.setVar('FILES_' + pkg, files)
}
