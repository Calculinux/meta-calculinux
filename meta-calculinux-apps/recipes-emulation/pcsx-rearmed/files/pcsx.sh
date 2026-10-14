#!/bin/sh
# PCSX-ReARMed standalone launcher.
#
# Sets sensible SDL defaults for the PicoCalc framebuffer console (same
# shape as picoarch's run_picoarch.sh). Every variable is overridable from
# the environment, e.g. SDL_VIDEODRIVER=x11 when running under QEMU.
#
# Settings, memcards and save states live in $HOME/.pcsx_rearmed/.

cd "$(dirname "$0")" || exit 1

export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-fbcon}"
export SDL_FBACCEL="${SDL_FBACCEL:-0}"
export SDL_FBDEV="${SDL_FBDEV:-/dev/fb0}"
export SDL_NOMOUSE="${SDL_NOMOUSE:-1}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"

exec ./pcsx.bin "$@"
