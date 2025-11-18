# Package Relocation Changes

## Summary
This update addresses name conflicts in the glkterm package by relocating interpreter binaries to a dedicated directory, and updates glkcli to find them at the new location.

## Changes Made

### 1. glkterm Recipe (`meta-calculinux-apps/recipes-games/glkterm/glkterm_git.bb`)
- **Version bump**: `1.0+git${SRCPV}` → `1.1+git${SRCPV}`
- **Binary relocation**: Interpreters now installed to `/usr/share/glkterm/bin/` instead of `/usr/bin/`
- **CMake configuration**: Added `EXTRA_OECMAKE = "-DCMAKE_INSTALL_BINDIR=${datadir}/${PN}/bin"`
- **FILES variable updated**: Removed `${bindir}/*` since binaries are no longer in standard location

**Rationale**: Multiple interpreters in glkterm have generic names that conflict with other packages when installed to `/usr/bin`. Moving them to `/usr/share/glkterm/bin` avoids these conflicts while keeping all related binaries together.

### 2. glkcli Source Code (`/home/benklop/repos/glkcli/src/launcher.rs`)
- **Added compile-time configuration**: The `find_interpreter_path()` method now checks for a `GLKTERM_BIN_DIR` environment variable at compile time using `option_env!()`.
- **Search order**:
  1. Configured installation directory (via `GLKTERM_BIN_DIR` at compile time)
  2. Development build directories (for local development)
  3. System PATH (fallback for alternative installations)
- **Tests updated**: Modified test to use unique interpreter name to avoid conflicts

**Rationale**: Using compile-time configuration via `option_env!()` is cleaner than runtime patches and allows the upstream code to support flexible deployment scenarios.

### 3. glkcli Recipe (`meta-calculinux-apps/recipes-games/glkcli/glkcli_git.bb`)
- **Version bump**: `1.0+git${SRCPV}` → `1.1+git${SRCPV}`
- **Added build-time environment variable**: `export GLKTERM_BIN_DIR = "${datadir}/glkterm/bin"`

**Rationale**: This passes the interpreter location to the Rust compiler, embedding it in the binary at compile time.

## Testing
- glkcli code compiled successfully with `cargo build --release`
- All unit tests pass (9/9 tests in launcher module)
- Code verified with `cargo check`

## Compatibility
- **Backward compatibility**: glkcli will still check PATH as a fallback, so custom installations outside the standard location will continue to work.
- **Runtime behavior**: When glkcli is built with the Yocto recipe, it will prefer `/usr/share/glkterm/bin` first, then fall back to other locations.
- **Development**: Local development builds will continue to work with the existing relative path checks.

## Files Modified
1. `/home/benklop/repos/calculinux/calculinux-build/meta-calculinux/meta-calculinux-apps/recipes-games/glkterm/glkterm_git.bb`
2. `/home/benklop/repos/glkcli/src/launcher.rs`
3. `/home/benklop/repos/calculinux/calculinux-build/meta-calculinux/meta-calculinux-apps/recipes-games/glkcli/glkcli_git.bb`
