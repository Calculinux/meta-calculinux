# GitHub Workflows Documentation

This directory contains the GitHub Actions workflows, reusable actions, and scripts for building and publishing Calculinux.

## Directory Structure

```
.github/
├── workflows/           # GitHub Actions workflow definitions
│   ├── build.yml       # Main build workflow
│   └── cleanall.yml    # Recipe cleaning workflow
├── actions/            # Reusable composite actions
│   ├── setup-build-env/     # Set up Yocto build environment
│   ├── sync-packages/       # Sync packages to repository
│   └── discord-notify/      # Send Discord notifications
└── scripts/            # Standalone bash/python scripts
    ├── determine-feed-config.sh     # Determine feed configuration
    ├── collect-images.sh            # Collect image artifacts
    ├── collect-packages.sh          # Collect package artifacts
    ├── collect-sdk.sh               # Collect SDK artifacts
    ├── publish-images.sh            # Publish images to webserver
    ├── publish-sdk.sh               # Publish SDKs to webserver
    └── generate-artifact-index.py   # Generate artifact index JSON
```

## Workflows

### build.yml
Main workflow for building Calculinux images, packages, and SDKs. Triggers on:
- Push to `main` or `develop` branches
- Tagged releases (`v*`)
- Pull requests to `main`
- Manual workflow dispatch

Key features:
- Builds Yocto images and packages
- Generates SDKs for x86_64 and aarch64
- Publishes artifacts to webserver
- Creates GitHub releases for tagged versions
- Sends Discord notifications for releases

### cleanall.yml
Workflow for cleaning BitBake recipes. Useful for forcing rebuilds or clearing cache.

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
    dl-dir: ${{ github.workspace }}/../yocto-cache/downloads
    sstate-dir: ${{ github.workspace }}/../yocto-cache/sstate-cache
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
Generates a JSON index of published artifacts for machine-readable access.

**Usage:**
```bash
./. github/scripts/generate-artifact-index.py \
  --base-url https://opkg.calculinux.org \
  --update-dir /path/to/update/dir \
  --image-dir /path/to/image/dir \
  --output /path/to/index.json \
  --feed-name walnascar \
  --subfolder continuous \
  --machine luckfox-lyra \
  --distro-version 1.0.0 \
  --git-sha abc123
```

## Adding a New Machine Configuration

To add a new machine (e.g., Raspberry Pi 4):

1. Update the `build.yml` workflow matrix:
```yaml
matrix:
  machine: [luckfox-lyra, rpi4]
  include:
    - machine: luckfox-lyra
      name: "Luckfox Lyra Bundle"
      kas_file: "kas-luckfox-lyra-bundle.yaml"
      target: "calculinux-bundle"
      dockerfile: "Dockerfile.aarch64"
    - machine: rpi4
      name: "Raspberry Pi 4 Bundle"
      kas_file: "kas-rpi4-bundle.yaml"
      target: "calculinux-bundle"
      dockerfile: "Dockerfile.arm64"
```

2. Create the corresponding kas configuration file (`kas-rpi4-bundle.yaml`)

3. All scripts and actions will automatically work with the new machine

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
