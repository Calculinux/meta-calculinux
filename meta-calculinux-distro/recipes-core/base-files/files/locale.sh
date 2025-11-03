# Set default locale to US English UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Enable Unicode support
case "$TERM" in
    linux)
        unicode_start
        ;;
esac
