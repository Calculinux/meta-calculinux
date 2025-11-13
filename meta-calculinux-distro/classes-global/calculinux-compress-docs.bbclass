# Automatically inherit compress_doc for recipes that install documentation
# This class is inherited globally via INHERIT_DISTRO

# Only inherit compress_doc if the recipe installs files to documentation directories
# This avoids unnecessary inheritance for recipes without docs

python () {
    # Check if this recipe might install documentation
    # Look for common documentation directories in FILES
    doc_features = d.getVar('DISTRO_FEATURES')
    if doc_features and 'doc' in doc_features:
        # Inherit compress_doc for recipes that are likely to have docs
        # This happens during recipe parsing
        bb.parse.BBHandler.inherit(['compress_doc'], 'calculinux-compress-docs.bbclass', 0, d)
}
