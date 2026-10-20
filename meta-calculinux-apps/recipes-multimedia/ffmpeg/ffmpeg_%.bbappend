# mpv (and so stmps) opens the https:// stream URLs of Subsonic servers through
# ffmpeg's protocol layer, which has no TLS unless a TLS library is enabled:
# without it playback fails at once with "No protocol handler found".
# GnuTLS rather than the recipe's openssl option, which forces
# --enable-nonfree. gnutls and its libraries are already on the image.
PACKAGECONFIG[gnutls] = "--enable-gnutls,--disable-gnutls,gnutls"
PACKAGECONFIG:append = " gnutls"

# Same version as the TLS-less package already in the feed; bump PR so opkg
# upgrades devices that have it installed.
PR = "r1"
