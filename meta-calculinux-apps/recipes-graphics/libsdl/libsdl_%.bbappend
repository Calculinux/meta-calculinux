# Ensure libSDL is compiled with fbcon support
EXTRA_OECONF = "--disable-static --enable-cdrom --enable-threads --enable-timers \
                --enable-file --disable-oss --disable-esd --disable-arts \
                --disable-diskaudio --disable-nas \
                --disable-mintaudio --disable-nasm --disable-video-dga \
                --disable-video-ps2gs --disable-video-ps3 \
                --disable-xbios --disable-gem --disable-video-dummy \
                --enable-input-events --enable-pthreads \
                --disable-video-svga \
                --disable-video-picogui --disable-video-qtopia --enable-sdl-dlopen \
                --disable-rpath"

# fbcon needs a kernel VT for its keyboard, which an app started from cruft
# (on a pty) doesn't have. Read and grab the keyboards through evdev instead,
# like the libsdl2 evdev patch does for KMSDRM, and don't trip over the
# SDL_VIDEODRIVER=kmsdrm that sdl2-defaults.sh exports for SDL 2.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " \
    file://0001-fbcon-read-keyboards-through-evdev-when-there-is-no-console.patch \
    file://0002-video-ignore-SDL_VIDEODRIVER-values-naming-an-unknown-driver.patch \
"
