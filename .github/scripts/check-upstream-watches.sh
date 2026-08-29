#!/usr/bin/env bash
# Check rotating unversioned upstream downloads and update recipes when the
# bytes change. BrosTrend-style URLs replace the file in place, which breaks
# do_fetch until SRC_URI[sha256sum] (and often PV) is bumped.
#
# Add another watch: write a function and call it from main().
set -euo pipefail

UA="calculinux-yocto-build (+https://calculinux.org)"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SUMMARY="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/upstream-watch-summary.md"
CHANGED=0
NOTES=()

user_agent_curl() {
    curl -fsSL --retry 3 --retry-delay 5 -A "$UA" "$@"
}

recipe_sha256() {
    local recipe="$1"
    sed -n 's/^SRC_URI\[sha256sum\] = "\([^"]*\)"/\1/p' "$recipe"
}

recipe_pv() {
    local recipe="$1"
    sed -n 's/^PV = "\([^"]*\)"/\1/p' "$recipe"
}

# ponytail: one handler for the one URL that has already broken the build twice.
# Next rotating deb can copy this and change the path/version-prefix bits.
watch_aic8800() {
    local dir="$ROOT/meta-calculinux-distro/recipes-connectivity/wifi-drivers"
    local url="https://linux.brostrend.com/aic8800-dkms.deb"
    local recipes=()
    shopt -s nullglob
    recipes=("$dir"/aic8800_*.bb)
    shopt -u nullglob
    if [ "${#recipes[@]}" -ne 1 ]; then
        echo "aic8800: expected one $dir/aic8800_*.bb, found ${#recipes[@]}" >&2
        return 1
    fi
    local recipe="${recipes[0]}"

    local old_sha old_pv
    old_sha="$(recipe_sha256 "$recipe")"
    old_pv="$(recipe_pv "$recipe")"
    if [ -z "$old_sha" ] || [ -z "$old_pv" ]; then
        echo "aic8800: could not read PV / sha256 from $recipe" >&2
        return 1
    fi

    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    echo "aic8800: fetching $url"
    user_agent_curl -o "$tmp/pkg.deb" "$url"
    local new_sha
    new_sha="$(sha256sum "$tmp/pkg.deb" | awk '{print $1}')"

    if [ "$new_sha" = "$old_sha" ]; then
        echo "aic8800: $old_pv unchanged ($old_sha)"
        NOTES+=("- aic8800 ${old_pv}: upstream sha256 matches")
        return 0
    fi

    dpkg-deb -x "$tmp/pkg.deb" "$tmp/root"
    local src_dir
    src_dir="$(find "$tmp/root/usr/src" -maxdepth 1 -type d -name 'aic8800-*' -printf '%f\n' | head -n 1)"
    if [ -z "$src_dir" ]; then
        echo "aic8800: deb layout changed; no usr/src/aic8800-* " >&2
        return 1
    fi
    local new_pv="${src_dir#aic8800-}"

    local new_lic=""
    if [ -f "$tmp/root/usr/share/doc/aic8800-dkms/copyright" ]; then
        new_lic="$(md5sum "$tmp/root/usr/share/doc/aic8800-dkms/copyright" | awk '{print $1}')"
    fi

    local patch_ok=1
    if [ -d "$tmp/root/usr/src/$src_dir" ]; then
        find "$tmp/root/usr/src/$src_dir" -type f \( -name '*.c' -o -name '*.h' -o -name 'Makefile' -o -name '*.makefile' \) \
            -exec sed -i 's/\r$//' {} +
        local patch
        for patch in "$dir/files"/0001-disable-werror-and-fix-address-check.patch \
                     "$dir/files"/0002-disable-ft-ies-update.patch; do
            if ! patch -p1 --dry-run --directory="$tmp/root/usr/src/$src_dir" < "$patch" >/dev/null; then
                echo "aic8800: $patch does not apply to $new_pv" >&2
                patch_ok=0
            fi
        done
    fi

    local dest="$dir/aic8800_${new_pv}.bb"
    if [ "$recipe" != "$dest" ]; then
        git -C "$ROOT" mv "$recipe" "$dest"
        recipe="$dest"
    fi

    sed -i \
        -e "s/^PV = \".*\"/PV = \"${new_pv}\"/" \
        -e "s/^SRC_URI\[sha256sum\] = \".*\"/SRC_URI[sha256sum] = \"${new_sha}\"/" \
        -e "s/(1\.0\.8 -> 1\.0\.9 -> ).* broke/(1.0.8 -> 1.0.9 -> ${new_pv} broke/" \
        -e "s/^# sha256 of the .* deb/# sha256 of the ${new_pv} deb/" \
        "$recipe"

    if [ -n "$new_lic" ]; then
        sed -i "s/copyright;md5=[0-9a-f]*/copyright;md5=${new_lic}/" "$recipe"
    fi

    if [ -f "$dir/AIC8800_FT_LIMITATION.md" ]; then
        sed -i "s|aic8800_[0-9.][0-9.]*\.bb|aic8800_${new_pv}.bb|" "$dir/AIC8800_FT_LIMITATION.md"
    fi

    CHANGED=1
    local patch_note="patches apply"
    if [ "$patch_ok" -eq 0 ]; then
        patch_note="WARNING: existing patches do not apply — recipe updated, patches need a human"
    fi
    NOTES+=("- aic8800 ${old_pv} -> ${new_pv} (sha256 ${old_sha} -> ${new_sha}); ${patch_note}")
    echo "aic8800: updated ${old_pv} -> ${new_pv}"
}

write_summary() {
    {
        echo "Scheduled check of unversioned upstream downloads that replace the file in place."
        echo
        for note in "${NOTES[@]}"; do
            echo "$note"
        done
    } > "$SUMMARY"
}

main() {
    cd "$ROOT"
    : > "$SUMMARY"
    watch_aic8800
    write_summary

    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        if [ "$CHANGED" -eq 1 ]; then
            echo "changed=true" >> "$GITHUB_OUTPUT"
        else
            echo "changed=false" >> "$GITHUB_OUTPUT"
        fi
        echo "summary<<EOF" >> "$GITHUB_OUTPUT"
        cat "$SUMMARY" >> "$GITHUB_OUTPUT"
        echo "EOF" >> "$GITHUB_OUTPUT"
    fi

    cat "$SUMMARY"
}

main "$@"
