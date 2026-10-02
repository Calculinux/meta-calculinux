#!/usr/bin/env python3
"""
Generate the index of emulator disk images the calculinux-emulator launcher
can offer: emulator/<machine>/index.json on the webserver.

Unlike generate-artifact-index.py (one index per feed/subfolder), this is a
single index across feeds, rebuilt from a scan of the repository on every
emulator publish: every tagged image kept under image/<feed>/release/ plus
the current image of each continuous feed. The un-versioned copy under
release/ ("latest release", fetched by older AppImages) is not listed.

publish-emulator.sh writes a <image>.qcow2.json sidecar next to each image
(id, channel, version, ...); images without one (published before the index
existed) get these from their path.
"""

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = 1
# Same test as determine-feed-config.sh.
PRERELEASE_RE = re.compile(r"(rc|beta|alpha)")
# Ids become directory names in the emulator's state directory.
ID_RE = re.compile(r"^[A-Za-z0-9_+-][A-Za-z0-9._+-]{0,63}$")
RESERVED_IDS = {"local", "custom", "legacy"}

CHANNEL_ORDER = {
    "continuous-main": 0,
    "continuous-develop": 1,
    "release": 2,
    "prerelease": 2,
}
CHANNEL_LABELS = {
    "continuous-main": "Latest (main)",
    "continuous-develop": "Latest (develop)",
}


def read_digest(path: Path) -> str:
    """Read SHA256 digest from .sha256 file or compute it."""
    sha_file = Path(f"{path}.sha256")
    if sha_file.exists():
        first_token = sha_file.read_text().strip().split()
        if first_token:
            return first_token[0]

    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def read_sidecar(path: Path) -> dict:
    sidecar = Path(f"{path}.json")
    if not sidecar.exists():
        return {}
    try:
        data = json.loads(sidecar.read_text())
    except (OSError, ValueError) as err:
        print(f"Ignoring unreadable sidecar {sidecar}: {err}", file=sys.stderr)
        return {}
    return data if isinstance(data, dict) else {}


def continuous_channel(feed: str) -> str:
    return "continuous-develop" if feed == "develop" else "continuous-main"


def make_entry(image: Path, feed: str, subfolder: str, base_url: str, defaults: dict):
    """Index entry for one image; the sidecar overrides the path-derived defaults."""
    info = {**defaults, **{k: v for k, v in read_sidecar(image).items() if v}}
    image_id = str(info["id"])
    if not ID_RE.match(image_id) or image_id in RESERVED_IDS:
        print(f"Skipping {image}: unusable id {image_id!r}", file=sys.stderr)
        return None

    stat = image.stat()
    channel = str(info["channel"])
    entry = {
        "id": image_id,
        "channel": channel,
        "label": CHANNEL_LABELS.get(channel, image_id),
        "version": str(info.get("version") or ""),
        "feed": feed,
        "subfolder": subfolder,
        "name": image.name,
        "size": stat.st_size,
        "sha256": read_digest(image),
        "last_modified": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
        "url": f"{base_url}/image/{feed}/{subfolder}/{image.name}",
    }
    if info.get("git_sha"):
        entry["git_sha"] = str(info["git_sha"])
    return entry


def collect_images(repo_dir: Path, base_url: str, machine: str):
    stem = f"calculinux-image-{machine}.rootfs"
    entries = {}

    def add(entry):
        if entry is None:
            return
        # The same id from two feeds (e.g. after a codename change): newest wins.
        current = entries.get(entry["id"])
        if current is None or entry["last_modified"] > current["last_modified"]:
            entries[entry["id"]] = entry

    image_root = repo_dir / "image"
    feeds = sorted(p for p in image_root.iterdir() if p.is_dir()) if image_root.is_dir() else []
    for feed_dir in feeds:
        feed = feed_dir.name

        release_dir = feed_dir / "release"
        if release_dir.is_dir():
            for image in sorted(release_dir.glob(f"{stem}-*.qcow2")):
                if image.is_symlink():
                    continue
                tag = image.name[len(stem) + 1:-len(".qcow2")]
                channel = "prerelease" if PRERELEASE_RE.search(tag) else "release"
                add(make_entry(image, feed, "release", base_url,
                               {"id": tag, "channel": channel, "version": tag}))

        image = feed_dir / "continuous" / f"{stem}.qcow2"
        if image.is_file() and not image.is_symlink():
            channel = continuous_channel(feed)
            add(make_entry(image, feed, "continuous", base_url,
                           {"id": channel, "channel": channel}))

    # Continuous images first, then tags, newest first.
    tags = sorted((e for e in entries.values() if CHANNEL_ORDER.get(e["channel"], 2) == 2),
                  key=lambda e: e["last_modified"], reverse=True)
    continuous = sorted((e for e in entries.values() if CHANNEL_ORDER.get(e["channel"], 2) < 2),
                        key=lambda e: CHANNEL_ORDER[e["channel"]])
    return continuous + tags


def main():
    parser = argparse.ArgumentParser(description="Generate the emulator image index JSON")
    parser.add_argument("--repo-dir", required=True, type=Path,
                        help="Webserver root (contains image/<feed>/<subfolder>/)")
    parser.add_argument("--base-url", default="https://opkg.calculinux.org",
                        help="URL the webserver root is served at")
    parser.add_argument("--machine", default="calculinux-qemuarm", help="Machine name")
    parser.add_argument("--output", type=Path, default=None,
                        help="Output file (default: <repo-dir>/emulator/<machine>/index.json)")
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    output = args.output or args.repo_dir / "emulator" / args.machine / "index.json"

    images = collect_images(args.repo_dir, base_url, args.machine)
    latest_release = next((e["id"] for e in images if e["channel"] == "release"), None)

    index = {
        "schema": SCHEMA,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "machine": args.machine,
        "latest_release": latest_release,
        "images": images,
    }

    # Replace atomically: clients may be fetching the index right now.
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(index, indent=2) + "\n")
    os.chmod(tmp, 0o644)
    os.replace(tmp, output)

    print(f"Generated emulator index: {output} ({len(images)} images)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
