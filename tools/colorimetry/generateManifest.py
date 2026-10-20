#!/usr/bin/env python3
"""Generate or verify the bundled colorimetry inventory from current files."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def manifest(root: Path) -> dict:
    """Use project-relative paths so the inventory survives installation moves."""
    folders = (
        "src/+colormeasure/+colorimetry",
        "resources/colorimetry",
        "tests/colorimetry",
        "docs/colorimetry",
        "tools/colorimetry",
    )
    paths = {
        path
        for folder in folders
        for path in (root / folder).rglob("*")
        if path.is_file() and path.suffix in {".m", ".py", ".md", ".csv", ".json", ".mat", ".txt"}
        and not any(part.startswith(".") or part == "__pycache__" for part in path.relative_to(root).parts)
    }
    paths.update(root / name for name in (
        "licenses/colorimetry-MIT.txt",
    ))
    return {
        "package": "colormeasure.colorimetry",
        "pathBase": "project root (folder containing src and resources)",
        "versionIdentity": "The Git commit containing this manifest identifies these files.",
        "upstream": {
            "repository": "https://github.com/RIT-MCSL/MCSL-Tools",
            "revision": "24f18e31c845a6c64e7b5d01f6fb227d12daeabc",
            "path": "Devices/measurement_v2/support_colorimetry",
        },
        "files": [
            {"path": str(path.relative_to(root)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            for path in sorted(paths)
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the saved inventory differs.")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    target = root / "resources/provenance/colorimetry-source.json"
    expected = json.dumps(manifest(root), indent=2) + "\n"
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != expected:
            raise SystemExit("Colorimetry inventory is stale; run tools/colorimetry/generateManifest.py.")
        print("Colorimetry inventory matches current files.")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(expected, encoding="utf-8")
        print(f"Updated {target.relative_to(root)}")


if __name__ == "__main__":
    main()
