#!/bin/sh
# Ensure user-installed packages in /usr/local are accessible
# Most systems already include /usr/local in PATH, but we ensure it here

# Prepend /usr/local binaries to PATH (should already be there, but guarantee it)
case ":$PATH:" in
    *:/usr/local/bin:*) ;;
    *) export PATH="/usr/local/bin:$PATH" ;;
esac

case ":$PATH:" in
    *:/usr/local/sbin:*) ;;
    *) export PATH="/usr/local/sbin:$PATH" ;;
esac

# Add /usr/local libraries to library search path
if [ -d /usr/local/lib ]; then
    case ":$LD_LIBRARY_PATH:" in
        *:/usr/local/lib:*) ;;
        *) export LD_LIBRARY_PATH="/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
fi

# Add pkg-config paths for building software
if [ -d /usr/local/lib/pkgconfig ]; then
    case ":$PKG_CONFIG_PATH:" in
        *:/usr/local/lib/pkgconfig:*) ;;
        *) export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" ;;
    esac
fi

if [ -d /usr/local/share/pkgconfig ]; then
    case ":$PKG_CONFIG_PATH:" in
        *:/usr/local/share/pkgconfig:*) ;;
        *) export PKG_CONFIG_PATH="/usr/local/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" ;;
    esac
fi

# Add man pages
if [ -d /usr/local/share/man ]; then
    case ":$MANPATH:" in
        *:/usr/local/share/man:*) ;;
        *) export MANPATH="/usr/local/share/man${MANPATH:+:$MANPATH}" ;;
    esac
fi
