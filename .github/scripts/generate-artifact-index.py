#!/usr/bin/env python3
"""
Generate artifact index JSON for published images and update bundles.
This provides a machine-readable catalog of available artifacts.
"""

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def read_digest(path: Path) -> str:
    """Read SHA256 digest from .sha256 file or compute it."""
    sha_file = Path(f"{path}.sha256")
    if sha_file.exists():
        first_token = sha_file.read_text().strip().split()
        if first_token:
            return first_token[0]
    
    # Compute digest if not found
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def collect_entries(root: Path, pattern: str, url_prefix: str, machine: str):
    """Collect artifact entries from a directory."""
    entries = []
    if not root.exists():
        return entries
    
    for artifact in sorted(root.glob(pattern)):
        # Skip checksum files and index itself
        if artifact.name.endswith(".sha256") or artifact.name == "index.json":
            continue
        if artifact.is_symlink():
            continue
        
        stat = artifact.stat()
        entries.append({
            "name": artifact.name,
            "machine": machine,
            "size": stat.st_size,
            "last_modified": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
            "sha256": read_digest(artifact),
            "url": f"{url_prefix}/{artifact.name}",
        })
    
    return entries


def main():
    parser = argparse.ArgumentParser(description="Generate artifact index JSON")
    parser.add_argument("--base-url", required=True, help="Base URL for artifacts")
    parser.add_argument("--update-dir", required=True, type=Path, help="Directory containing RAUC bundles")
    parser.add_argument("--image-dir", required=True, type=Path, help="Directory containing WIC images")
    parser.add_argument("--output", required=True, type=Path, help="Output JSON file path")
    parser.add_argument("--feed-name", required=True, help="Feed name")
    parser.add_argument("--subfolder", required=True, help="Subfolder (continuous/release)")
    parser.add_argument("--machine", required=True, help="Machine name")
    parser.add_argument("--distro-version", required=True, help="Distro version")
    parser.add_argument("--git-sha", required=True, help="Git commit SHA")
    
    args = parser.parse_args()
    
    # Collect artifacts
    rauc_bundles = collect_entries(
        args.update_dir,
        "*.raucb",
        f"/update/{args.feed_name}/{args.subfolder}",
        args.machine,
    )
    
    wic_images = collect_entries(
        args.image_dir,
        "*.wic*",
        f"/image/{args.feed_name}/{args.subfolder}",
        args.machine,
    )
    
    # Build index structure
    index = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "machine": args.machine,
        "feed": args.feed_name,
        "subfolder": args.subfolder,
        "distro_version": args.distro_version,
        "git_sha": args.git_sha,
        "artifacts": {
            "rauc": rauc_bundles,
            "images": wic_images,
        },
    }
    
    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(index, indent=2))
    
    print(f"Wrote index to {args.output}")
    print(f"  RAUC bundles: {len(rauc_bundles)}")
    print(f"  WIC images: {len(wic_images)}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
