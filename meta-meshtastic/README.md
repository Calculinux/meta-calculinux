# Meta Calculinux Meshtastic Layer

This layer provides recipes for building the Meshtastic native daemon and its supporting utilities.

## Provided recipes

- `meshtasticd`: Builds the Meshtastic Linux daemon from the upstream firmware Portduino environment using PlatformIO.
- `python3-platformio`: Host and target builds for the PlatformIO core tooling required to build `meshtasticd`.

## Adding the layer

Add this layer to your `bblayers.conf` alongside the other Calculinux layers, for example:

```
BBLAYERS += "${TOPDIR}/../meta-calculinux/meta-meshtastic"
```

Ensure the dependencies listed in `conf/layer.conf` (core layers plus Python support from meta-python/meta-openembedded) are present in your build configuration.

## Notes

- The current Meshtastic Portduino build still expects to download its PlatformIO package dependencies from the network during compilation. The recipe allows network access for `do_compile` until the remaining packages are mirrored locally.
- Optional PACKAGECONFIG flags enable Avahi advertisement support (`avahi`) and pull in the libulfius stack required for the experimental web interface (`web`).
