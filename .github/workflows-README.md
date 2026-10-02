# GitHub Workflows Documentation

This directory contains the GitHub Actions workflows, reusable actions, and scripts for building and publishing Calculinux.

## Directory Structure

```
.github/
├── workflows/           # GitHub Actions workflow definitions
│   ├── build-hosted.yml     # Main build ("Build Calculinux"), GitHub-hosted
│   ├── yocto-pass.yml       # One time-boxed build pass (called by build-hosted, qemu-boot)
│   ├── qemu-boot.yml        # calculinux-qemuarm boot tests + emulator AppImages, GitHub-hosted
│   ├── publish-pr.yml       # Publish PR builds to the PR channel + testing feed
│   ├── pr-rauc-cleanup.yml  # Remove a closed PR's published artifacts
│   ├── build.yml            # Manual fallback build on the self-hosted runners
│   └── cleanall.yml         # Recipe cleaning workflow
├── actions/            # Reusable composite actions
│   ├── setup-build-env/     # Set up Yocto build environment
│   ├── sync-packages/       # Sync packages to repository
│   └── discord-notify/      # Send Discord notifications
└── scripts/            # Standalone bash/python scripts
    ├── lib/                        # Shared helpers (sourced by other scripts)
    │   ├── publish-common.sh       # Arg parsing + paths for publish-images, publish-sdk
    │   ├── copy-with-checksum.sh   # cp + sha256sum helper
    │   ├── index-feed.sh           # Regenerate Packages.gz for one feed arch dir
    │   └── testing-feed.sh         # Testing-feed manifests, locking, reindexing
    ├── yocto-pass.sh               # Run one time-boxed pass of a lane (image or sdk)
    ├── prune-sstate.sh             # Shrink sstate to the build's working set before caching
    ├── select-sdk-sstate.sh        # Stage the SDK lane's own sstate for its cache entry
    ├── rotate-caches.sh            # Keep the newest N Actions cache entries per prefix
    ├── list-new-packages.sh        # List the IPKs a workflow run built (drops per-commit churners)
    ├── publish-testing-packages.sh # Publish a PR's packages to the testing feed
    ├── cleanup-testing-packages.sh # Remove a closed PR's packages from the testing feed
    ├── sync-source-mirror.sh       # Keep the /.sources download mirror current
    ├── qemu-image-tests.sh         # post_build: runqemu boot + overlayfs tests (qemuarm)
    ├── qemu-appimage-test.sh       # post_build: boot test of the x86_64 emulator AppImage
    ├── build-dir.sh                # Find Yocto build directory (used by collect-*)
    ├── determine-feed-config.sh    # Determine feed configuration
    ├── load-script-output.sh       # Run script and load key=value output to GITHUB_OUTPUT
    ├── cleanup-pr-bundle.sh        # Remove PR RAUC bundle and refresh channel index
    ├── collect-images.sh           # Collect image artifacts
    ├── collect-packages.sh          # Collect package artifacts
    ├── collect-sdk.sh              # Collect SDK artifacts
    ├── publish-images.sh          # Publish images to webserver
    ├── publish-sdk.sh             # Publish SDKs to webserver
    └── generate-artifact-index.py  # Generate artifact index JSON
```

## Workflows

### build-hosted.yml ("Build Calculinux")
Main build, on free GitHub-hosted runners. Triggers on pushes to `main` and
`develop`, `v*` tags, PRs to `main`, and manual dispatch (with
`sync_all_packages`).

A cold build does not fit the 6 hour hosted-job limit on 4 cores, so each lane
runs as a chain of identical time-boxed passes (`yocto-pass.yml`): a warm build
finishes in its first pass and later passes are skipped; a cold one resumes from
the sstate the previous pass handed over as a run artifact.

- `pass1..3`: image, bundle and packages.
- `sdk1..3`: both SDKs, published refs only, after the image chain.
- `publish` (self-hosted): publishes the artifacts to the opkg server (feed,
  images, index, SDKs, releases, Discord) and keeps the `/.sources` download
  mirror current. Hosted runners cannot reach the server themselves.

**Caches.** sstate is kept in the Actions cache (repo limit 50 GB), keyed by
Yocto release so releases never evict each other: the two newest
`sstate-<release>-<machine>-img-` entries and the newest `...-sdk-` entry.
Only pushes to `main` save; PR builds only read. Sources come lazily from
`https://opkg.calculinux.org/.sources/`, then the Yocto source mirror, then upstream.

### qemu-boot.yml
Builds `calculinux-qemuarm` and the `calculinux-emulator` AppImages on
GitHub-hosted runners, with the same pass chains and caches as
`build-hosted.yml` (cache keys are per machine):

- `pass1..3`: the image; the finishing pass runs the runqemu boot and
  overlayfs tests (`qemu-image-tests.sh`) and hands its sstate to the next lane.
- `emu1..3` (`emulator` lane): the AppImages for both hosts and the disk image
  they boot; the finishing pass boot-tests the x86_64 AppImage
  (`qemu-appimage-test.sh`).
- `publish` (self-hosted, published refs only): publishes the emulator next
  to the SDKs and attaches it to tagged releases, then rebuilds
  `emulator/calculinux-qemuarm/index.json` (`generate-emulator-index.py`):
  one index of every tagged disk image under `image/<feed>/release/` and the
  current `main` and `develop` images, whichever ref published last.

Test time is reserved out of each pass's build budget (`post_build_minutes`),
so tests always fit in the job. Serial logs are uploaded as `test-logs-*`.

### publish-pr.yml
Runs after a successful PR build of "Build Calculinux", from `main`'s code only
(it never checks out PR code), on a self-hosted runner:
- RAUC bundle and WIC image go to the PR channel (`update|image/<feed>/pr/`).
- The packages the PR built (new or changed relative to `main`'s cache) go to
  the shared **testing feed**, `ipk/<feed>/testing/<arch>/`. The PR comment
  lists them with the `src/gz` lines to add on a device. Packages that
  rebuild on every commit because their content embeds
  `DISTRO_VERSION`/`MACHINE` (today: `os-release`, `base-files` and their
  split/sub packages — see `SKIP_PKGS` in `scripts/list-new-packages.sh`)
  are dropped from the list, unless the PR's diff touches the package's
  recipe, in which case they are kept.
- Same-repo PRs always publish. Fork PRs publish only once a maintainer adds
  the `publish-testing` label, which publishes the PR head's latest build.

### pr-rauc-cleanup.yml
When a PR closes (merged or not), removes its bundle and image and its
testing-feed packages. A package another open PR also published stays until
that PR closes too; `ipk/<feed>/testing/.manifests/pr<N>.txt` records which
PR published what.

### build.yml
The previous self-hosted build, now **manual only** (workflow dispatch) as a
fallback. It still builds and publishes the way it always did.

### cleanall.yml
Workflow for cleaning BitBake recipes. Useful for forcing rebuilds or clearing cache.

### upstream-watches.yml
Daily (and manual) check of unversioned upstream downloads that replace the file in place. Today that is the BrosTrend `aic8800-dkms.deb`. When the sha256 or packaged version changes, the workflow updates the recipe and opens or refreshes `chore/upstream-watches`. Add another source in `.github/scripts/check-upstream-watches.sh`.

## Reusable Actions

### setup-build-env
Sets up the Yocto build environment with cache directories and verification.

**Inputs:**
- `dl-dir`: Downloads directory path (required)
- `sstate-dir`: Shared state cache directory path (required)
- `opkg-repo-dir`: Package repository directory path (optional)

**Usage:**
```yaml
- uses: ./.github/actions/setup-build-env
  with:
    dl-dir: /mnt/runner-cache/yocto-cache/downloads
    sstate-dir: /mnt/runner-cache/yocto-cache/sstate-cache
    opkg-repo-dir: /mnt/opkg-repo
```

### sync-packages
Syncs IPK packages to the repository and generates opkg package indexes.

**Inputs:**
- `opkg-repo-dir`: Package repository root directory (required)
- `feed-name`: Feed name, e.g., walnascar, develop (required)
- `subfolder`: Subfolder - continuous, release, or branch (required)
- `artifacts-dir`: Directory containing built packages (required)
- `sync-all`: Sync all packages instead of just newly built (optional, default: false)
- `package-list`: File listing newly built packages as `<arch>/<file>.ipk` (optional). When
  present, those plus any missing from the feed are synced instead of guessing from mtimes,
  which artifact downloads do not preserve. `build-hosted.yml` passes the list `yocto-pass.yml` records.

**Usage:**
```yaml
- uses: ./.github/actions/sync-packages
  with:
    opkg-repo-dir: /mnt/opkg-repo
    feed-name: walnascar
    subfolder: continuous
    artifacts-dir: ./artifacts
```

### discord-notify
Sends a Discord notification for Calculinux releases with download links.

**Inputs:**
- `webhook-url`: Discord webhook URL (required)
- `machine`: Target machine name (required)
- `feed-name`: Feed name (required)
- `subfolder`: Feed subfolder (required)
- `is-prerelease`: Whether this is a prerelease (required)
- `tag-name`: Git tag name (required)
- `run-number`: GitHub workflow run number (required)
- `release-url`: URL to the GitHub release (required)
- `artifacts-dir`: Directory containing build artifacts (required)
- `opkg-repo-base`: Base URL for opkg repository (optional)

**Usage:**
```yaml
- uses: ./.github/actions/discord-notify
  if: steps.feed-config.outputs.is_tagged_release == 'true'
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK_URL }}
    machine: luckfox-lyra
    feed-name: ${{ steps.feed-config.outputs.feed_name }}
    subfolder: ${{ steps.feed-config.outputs.subfolder }}
    is-prerelease: ${{ steps.feed-config.outputs.is_prerelease }}
    tag-name: ${{ github.ref_name }}
    run-number: ${{ github.run_number }}
    release-url: https://github.com/${{ github.repository }}/releases/tag/${{ github.ref_name }}
    artifacts-dir: ./artifacts
```

## Scripts

### determine-feed-config.sh
Determines feed configuration based on Git ref (branch or tag).

**Usage:**
```bash
./.github/scripts/determine-feed-config.sh <kas_file> <ref_name> <ref_type>
```

**Outputs** (one per line):
- `feed_name`: Feed name
- `subfolder`: Subfolder path
- `is_prerelease`: true/false
- `is_tagged_release`: true/false
- `is_published_branch`: true/false
- `distro_codename`: Distro codename
- `feed_subfolder`: Feed subfolder for URLs

### collect-images.sh
Collects image build artifacts (WIC images, RAUC bundles, u-boot files).

**Usage:**
```bash
./.github/scripts/collect-images.sh <machine> <artifacts_dir>
```

### collect-packages.sh
Collects IPK package build artifacts maintaining architecture structure.

**Usage:**
```bash
./.github/scripts/collect-packages.sh <artifacts_dir>
```

### collect-sdk.sh
Collects SDK build artifacts organized by architecture (x86_64, aarch64).

**Usage:**
```bash
./.github/scripts/collect-sdk.sh <artifacts_dir>
```

### publish-images.sh
Publishes image artifacts to webserver with appropriate versioning.

**Usage:**
```bash
./.github/scripts/publish-images.sh <opkg_repo_dir> <feed_name> <subfolder> \
  <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>
```

### publish-sdk.sh
Publishes SDK artifacts to webserver organized by architecture.

**Usage:**
```bash
./.github/scripts/publish-sdk.sh <opkg_repo_dir> <feed_name> <subfolder> \
  <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>
```

### generate-artifact-index.py
Generates a JSON index of published artifacts for machine-readable access. Used for both PR channels (RAUC bundles only) and release channels (RAUC bundles + WIC images).

**Release channel usage:**
```bash
./.github/scripts/generate-artifact-index.py \
  --base-url https://opkg.calculinux.org \
  --update-dir /path/to/update/dir \
  --image-dir /path/to/image/dir \
  --output /path/to/index.json \
  --feed-name walnascar \
  --subfolder release \
  --machine luckfox-lyra \
  --distro-version 1.0.0 \
  --git-sha abc123
```

**PR channel usage** (omit --image-dir, --distro-version, --git-sha; add --is-pr-channel):
```bash
./.github/scripts/generate-artifact-index.py \
  --base-url https://opkg.calculinux.org \
  --update-dir /path/to/pr/dir \
  --output /path/to/pr/dir/index.json \
  --feed-name walnascar \
  --subfolder pr \
  --machine luckfox-lyra \
  --is-pr-channel
```

## Adding a New Machine Configuration

The hosted build (`build-hosted.yml`) builds one machine today: `yocto-pass.yml`
takes `machine` and `kas_file` inputs (default `luckfox-lyra` and
`kas-luckfox-lyra-bundle.yaml`), and the `publish` job and `publish-pr.yml` set
`MACHINE`. To add a machine:

1. Create its kas configuration file (e.g. `kas-rpi4-bundle.yaml`).
2. In `build-hosted.yml`, add a pass chain (and SDK chain if it ships SDKs) that
   passes the new `machine` and `kas_file` to `yocto-pass.yml`. Cache keys,
   deltas and artifacts are already named per machine.
3. Publish its artifacts: extend the `publish` job and `publish-pr.yml`, which
   currently handle one `MACHINE`.

## Modifying Workflows

When modifying workflows:

1. **Extract complex logic** to scripts in `.github/scripts/`
2. **Create reusable actions** for common multi-step operations in `.github/actions/`
3. **Keep workflows clean** and focused on orchestration
4. **Test thoroughly** - these workflows control production releases
5. **Document changes** in this README

## Best Practices

- **Scripts should be self-contained** with clear usage messages
- **Actions should have comprehensive input validation**
- **Use set -euo pipefail** in bash scripts for error handling
- **Make scripts executable**: `chmod +x .github/scripts/*.sh`
- **Test scripts locally** before committing
- **Update documentation** when adding or changing scripts/actions

## Troubleshooting

### Build fails to find artifacts
Check that the artifact collection scripts are finding the correct build directories. The scripts look for directories under `build/*/tmp/deploy/`.

### Package sync doesn't update packages
Verify that `sync-all` is set appropriately. By default, only packages modified within the last 5 minutes are synced.

### Discord notification fails
Ensure the `DISCORD_WEBHOOK_URL` secret is configured in the repository settings.

### Feed configuration incorrect
Check the output of `determine-feed-config.sh` to verify it's detecting the branch/tag correctly.
