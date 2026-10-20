#!/usr/bin/env python3
"""Reproduce structural chart definitions from authenticated Argyll 3.5.0 files.

No color values or source target files are copied. This intentionally reads the
verified identifier/location columns of these two pinned files only; it is not
a general CGATS reader and does not relax the application's strict reader.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex

ROOT = Path(__file__).resolve().parents[2]
SOURCE_HASHES = {
    "ref/ColorChecker.ti2": "cb05ea088ba197b37b1c478c26d32f59a6bc74de4f7a6710b9ff2ad229b10c11",
    "ref/ColorCheckerSG.ti2": "687a880a00ea0f732ddcd0c249ed9198d8fe015168acc3c13915b085b54a4f21",
}
SOURCE_TERMS_HASHES = {
    "ref/ReadMe.txt": "d86b4cb70d555b9f6387d0861367333b42f6529b672547948eb11f850ad7459a",
    "ref/License.txt": "432d251a78dbc966e6add13f9f3b40a53daca222208e50cb514cfc77e7d85af6",
}
CLASSIC_NAMES = (
    "Dark skin", "Light skin", "Blue sky", "Foliage", "Blue flower", "Bluish green",
    "Orange", "Purplish blue", "Moderate red", "Purple", "Yellow green", "Orange yellow",
    "Blue", "Green", "Red", "Yellow", "Magenta", "Cyan", "White", "Neutral 8",
    "Neutral 6.5", "Neutral 5", "Neutral 3.5", "Black",
)
NAMES_SOURCE = "https://www.xrite.com/-/media/xrite/files/literature/misc/c/cxf3_schema_overview_en.pdf"


def encoded(value: dict) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_locations(source: Path, relative: str, count: int) -> list[tuple[int, str]]:
    raw = (source / relative).read_bytes()
    if sha256(raw) != SOURCE_HASHES[relative]:
        raise ValueError(f"Source digest differs from pinned Argyll 3.5.0: {relative}")
    text = raw.decode("utf-8")
    lines = text.splitlines()
    start, finish = lines.index("BEGIN_DATA"), lines.index("END_DATA")
    rows = [shlex.split(line) for line in lines[start + 1:finish] if line.strip()]
    if len(rows) != count or any(len(row) != 8 for row in rows):
        raise ValueError(f"Pinned structural census failed: {relative}")
    # Classic declares nine fields but contains eight. The exact source hash
    # and this source-specific eight-field census preserve that documented
    # defect without weakening any general format parser.
    return [(int(row[0]), row[1]) for row in rows]


def build(source: Path, kind: str) -> dict:
    classic = kind == "classic"
    rows, columns = (4, 6) if classic else (10, 14)
    relative = "ref/ColorChecker.ti2" if classic else "ref/ColorCheckerSG.ti2"
    locations = read_locations(source, relative, rows * columns)
    by_cell = {}
    for export_id, (raw_id, location) in enumerate(locations, 1):
        match = re.fullmatch(r"([A-Z])([0-9]+)", location)
        if match is None:
            raise ValueError(f"Unexpected source location: {location}")
        letter, number = ord(match[1]) - 64, int(match[2])
        row, column = (letter, number) if classic else (number, letter)
        if not 1 <= row <= rows or not 1 <= column <= columns or (row, column) in by_cell:
            raise ValueError("Source location map is not a complete grid")
        if classic and raw_id != (row - 1) * columns + column:
            raise ValueError("Classic source numbering changed")
        if not classic and (location != f"{chr(64 + column)}{row:02d}" or
                            export_id != (column - 1) * rows + row or
                            raw_id != (26 if location == "C07" else export_id)):
            raise ValueError("SG source ordering or documented duplicate changed")
        by_cell[row, column] = {
            "row": row, "column": column, "sourceLocation": location,
            "sourceId": raw_id, "exportId": export_id,
            "patchNumber": raw_id if classic else None,
            "patchName": CLASSIC_NAMES[raw_id - 1] if classic else "",
        }
    return {
        "id": "colorchecker-classic" if classic else "colorchecker-digital-sg",
        "revision": "argyll-3.5.0-structure-v1", "kind": kind,
        "name": "ColorChecker Classic" if classic else "ColorChecker Digital SG",
        "rows": rows, "columns": columns, "traversal": "row-major-v1",
        "cells": [by_cell[row, column] for row in range(1, rows + 1) for column in range(1, columns + 1)],
        "provenance": {
            "source": f"ArgyllCMS 3.5.0 {relative}",
            "sourceLocationScheme": "Source row letters and column numbers" if classic else "Source column letters and zero-padded row numbers; column-major source order",
            "referenceData": "Not part of the structural definition; expected illustrations are frozen separately",
        },
        "referenceConditions": {
            "edition": "Source created 11 April 2007; physical chart edition unverified" if classic else "Source created 10 February 2014; physical chart edition unverified",
            "illuminant": "Unspecified for this structural definition",
            "observer": "Unspecified for this structural definition",
            "scale": "Unspecified for this structural definition",
        },
    }


def outputs(source: Path) -> dict[str, bytes]:
    for path, digest in SOURCE_TERMS_HASHES.items():
        if sha256((source / path).read_bytes()) != digest:
            raise ValueError(f"Source terms differ from pinned Argyll 3.5.0: {path}")
    files = {f"resources/charts/{kind}.json": encoded(build(source, kind)) for kind in ("classic", "sg")}
    manifest = {
        "format": "chart-definitions", "version": 1,
        "package": "colormeasure.chart", "pathBase": "project root",
        "generator": {"path": "tools/charts/generateDefinitions.py", "revision": "structural-v1", "sha256": sha256(Path(__file__).read_bytes())},
        "upstream": {"release": "ArgyllCMS 3.5.0", "archive": "https://www.argyllcms.com/Argyll_V3.5.0_src.zip", "archiveSHA256": "f8576ce5589fd15620abb73ff049ea31f55ddbd1bba6d1ffa87452658e7bc85f", "files": [{"path": path, "sha256": digest} for path, digest in (SOURCE_HASHES | SOURCE_TERMS_HASHES).items()]},
        "mappingCorrections": [
            "Classic source A2 maps to application B1 (patch 2); source B1 maps to application A2 (patch 7).",
            "Classic declares nine fields but contains eight; this source-specific generator extracts only authenticated structural identifiers.",
            "SG source locations preserve column-major order and zero padding. C06 and C07 retain raw sourceId 26; C07 exportId is corrected to 27."
        ],
        "patchNamesSource": NAMES_SOURCE,
        "permittedDataUse": "These structural mappings retain source-derived identifiers from ArgyllCMS 3.5.0 under AGPL-3.0. The authenticated ref/ReadMe.txt assigns both source targets to ref/License.txt; the verbatim terms are retained in resources/charts/ARGYLL-AGPL-3.0.txt. The application's MIT license does not relabel this material. Section 2 permits local use and local copies not conveyed to others. Local testing copies retain the complete resources, generator, attribution and license. External distribution requires a separate assessment of the combined distribution and corresponding-source obligations. This structural generator supplies no numerical palette. Separate frozen historical illustrations and original numerical sources retain their own chart-reference-source.json manifest and the same source terms.",
        "redistributionStatus": "AGPL-3.0 terms retained; local testing copies permitted; external distribution not cleared",
        "sourceTerms": {"license": "AGPL-3.0", "path": "resources/charts/ARGYLL-AGPL-3.0.txt", "sha256": SOURCE_TERMS_HASHES["ref/License.txt"]},
        "files": [{"path": path, "sha256": sha256(raw)} for path, raw in files.items()],
    }
    files["resources/provenance/chart-source.json"] = encoded(manifest)
    files["resources/charts/ARGYLL-AGPL-3.0.txt"] = (source / "ref/License.txt").read_bytes()
    return files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--argyll-source", type=Path, required=True, help="Authenticated extracted Argyll_V3.5.0 folder")
    parser.add_argument("--check", action="store_true", help="Compare reproduced outputs without changing any file")
    args = parser.parse_args()
    files = outputs(args.argyll_source)
    manifest_digest = sha256(files["resources/provenance/chart-source.json"])
    helper = ROOT / "src/+colormeasure/+chart/private/packagedDefinition.m"
    original = helper.read_text(encoding="utf-8")
    expected, count = re.subn(r"manifestDigest = '[^']+';", f"manifestDigest = '{manifest_digest}';", original)
    if count != 1:
        raise SystemExit("Manifest digest anchor is missing or ambiguous")
    if args.check:
        stale = [path for path, raw in files.items() if not (ROOT / path).is_file() or (ROOT / path).read_bytes() != raw]
        if original != expected:
            stale.append(str(helper.relative_to(ROOT)))
        if stale:
            raise SystemExit("Chart definitions differ from pinned sources: " + ", ".join(stale))
        print("Classic 24 and SG 140 structural mappings and pinned digests reproduce exactly.")
    else:
        for path, raw in files.items():
            target = ROOT / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        helper.write_text(expected, encoding="utf-8")
        print("Generated Classic and SG definitions, provenance and runtime digest anchor.")


if __name__ == "__main__":
    main()
