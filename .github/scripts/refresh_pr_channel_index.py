#!/usr/bin/env python3
"""Regenerate the index.json for the PR update channel."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Filesystem path for the PR channel")
    parser.add_argument("--base-url", required=True, help="Public base URL (e.g. https://opkg.calculinux.org)")
    parser.add_argument("--channel-path", required=True, help="Mirror path (e.g. /update/luckfox-lyra/pr)")
    parser.add_argument("--machine", required=True, help="Machine name for metadata")
    parser.add_argument("--feed", help="Feed/codename identifier")
    parser.add_argument("--subfolder", help="Subfolder identifier")
    return parser.parse_args()


def compute_sha256(path: Path) -> str:
    sha_file = Path(f"{path}.sha256")
    if sha_file.exists():
        token = sha_file.read_text().strip().split()
        if token:
            return token[0]
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def build_index(args: argparse.Namespace) -> dict:
    channel_parts = args.channel_path.strip("/").split("/")
    feed = args.feed or (channel_parts[1] if len(channel_parts) > 1 else "")
    subfolder = args.subfolder or ("/".join(channel_parts[2:]) if len(channel_parts) > 2 else "")

    entries = []
    if args.root.exists():
        for bundle in sorted(args.root.glob("*.raucb")):
            if bundle.is_symlink():
                continue
            stat = bundle.stat()
            entries.append(
                {
                    "name": bundle.name,
                    "size": stat.st_size,
                    "last_modified": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
                    "sha256": compute_sha256(bundle),
                    "url": f"{args.base_url}{args.channel_path}/{bundle.name}",
                }
            )

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "machine": args.machine,
        "feed": feed,
        "subfolder": subfolder,
        "is_pr_channel": True,
        "artifacts": {
            "rauc": entries,
            "images": [],
        },
    }


def main() -> None:
    args = parse_args()
    args.root.mkdir(parents=True, exist_ok=True)
    index = build_index(args)
    output_path = args.root / "index.json"
    output_path.write_text(json.dumps(index, indent=2))


if __name__ == "__main__":
    main()
