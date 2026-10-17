SUMMARY = "Bluetooth management TUI for Linux"
DESCRIPTION = "A terminal application for managing bluetooth: toggle adapter \
power and discoverability, pair, unpair, trust and favorite devices, and \
rename aliases. Talks to bluetoothd over D-Bus."
HOMEPAGE = "https://github.com/pythops/bluetui"
SECTION = "console/network"

# SPDX 3.x renames the former "GPL-3.0" ID to GPL-3.0-only; upstream's own
# packaging (package.nix) declares gpl3Only.
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

# Tag v0.8.2 (SRCREV is the tag's commit)
SRC_URI = "git://github.com/pythops/bluetui.git;protocol=https;branch=master"
SRCREV = "e4d30d3396953dc512cf8c593f16a4dc7d0c5d79"

S = "${WORKDIR}/git"

# Rust build system - use cargo-update-recipe-crates for proper dependency management
inherit cargo cargo-update-recipe-crates

# Use --offline instead of --frozen so cargo uses the bitbake-vendored crates
# without strict lockfile checks that can fail when directory source resolution
# differs slightly from the registry.
CARGO_BUILD_FLAGS:remove = "--frozen"
CARGO_BUILD_FLAGS += "--offline"

# Upstream's [profile.release] sets strip = true, so cargo delivers an
# already-stripped binary and do_package dies on the "already-stripped"
# QA error (no debug info, no .debug package). Override the profile from
# the build flags instead, leaving stripping to the distribution's
# do_package like for every other recipe.
CARGO_BUILD_FLAGS += "--config profile.release.strip=false"

# libdbus-sys builds its vendored libdbus C sources with the cc crate during
# the cargo build. Unlike rustc (whose output paths are remapped by
# RUST_DEBUG_REMAP in rust-common), those C objects keep their absolute
# build paths in the DWARF, which the buildpaths QA rejects in the -dbg
# package. Append a prefix map for C so the cc invocations (which honour
# CFLAGS) remap the workspace like the rest of the build does. Appended
# after the DEBUG_PREFIX_MAP entries so the more specific ${S}/${B} maps
# keep winning.
CFLAGS:append = " -ffile-prefix-map=${WORKDIR}=${TARGET_DBGSRC_DIR}"

# Runtime dependency on the bluetooth stack (bluetoothd over D-Bus)
RDEPENDS:${PN} = "bluez5"

# Include the auto-generated crates file
require ${BPN}-crates.inc

# Package files
FILES:${PN} = "${bindir}/bluetui"

# This is a CLI tool, no development or library files expected
FILES:${PN}-dev = ""
