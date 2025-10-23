# Set default locale to US English UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Ensure terminal supports UTF-8
# If TERM is not already set to a UTF-8 variant, we'll keep the base TERM
# but most modern terminals should handle UTF-8 with the locale settings above
case "$TERM" in
    linux)
        # For Linux console, we could use linux but it should work with just locale
        ;;
esac
