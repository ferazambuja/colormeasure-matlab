#!/usr/bin/env python3
"""Freeze historical Argyll reference illustrations, not specimen standards.

Generation reuses color_measurement.cgats and science.lab_to_xyz. Runtime
MATLAB needs neither Python nor an Argyll checkout. Original numerical files
and their AGPL terms accompany the derived data; device RGB is never sRGB.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
PINS = {
    "ref/ColorChecker.cie": "68d5ef73507a577fbe78ffac8576c9b1cf2e91a8f88d5099f7bba648b38266ec",
    "ref/ColorCheckerSG.ti2": "687a880a00ea0f732ddcd0c249ed9198d8fe015168acc3c13915b085b54a4f21",
    "ref/ReadMe.txt": "d86b4cb70d555b9f6387d0861367333b42f6529b672547948eb11f850ad7459a",
    "ref/License.txt": "432d251a78dbc966e6add13f9f3b40a53daca222208e50cb514cfc77e7d85af6",
    "spectro/chartread.c": "564d7efc32ee7f8973cc8fd82e666eed19ee0e559df0a57ccd824f7583e705c7",
    "scanin/scanin.c": "6faf7096285a7694e3d935aca0ed8f6ced3baf20f683f8740763a45dd5101831",
    "icc/icc_util.c": "e106aae34dceace237b0654682591d6dea7a7d2841e7ed1db16cd3e551f083f6",
}


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def encode(value: dict) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode()


def outputs(source: Path, python_project: Path) -> dict[str, bytes]:
    original = {name: (source / name).read_bytes() for name in PINS}
    for name, raw in original.items():
        if digest(raw) != PINS[name]:
            raise ValueError(f"Source differs from pinned Argyll interpretation: {name}")
    sys.path.insert(0, str(python_project / "src"))
    from color_measurement.cgats import read_cgats
    from color_measurement.science import lab_to_xyz
    import color_measurement.cgats as cgats
    import color_measurement.science as science

    # icc_util.c rounds positive ICC D50 components to s15Fixed16, then *100.
    white = [int(value * 65536 + .5) / 65536 * 100 for value in (.9642, 1, .8249)]
    result = {}
    for kind, relative, fields, identifier in (
        ("classic", "ref/ColorChecker.cie", ("LAB_L", "LAB_A", "LAB_B"), "IT8.7/2"),
        ("sg", "ref/ColorCheckerSG.ti2", ("XYZ_X", "XYZ_Y", "XYZ_Z"), "CTI2"),
    ):
        tables = read_cgats(original[relative].decode("utf-8"), expected_identifier=identifier)
        if len(tables) != 1:
            raise ValueError("Expected exactly one reference table")
        table = tables[0]
        definition = json.loads((ROOT / f"resources/charts/{kind}.json").read_bytes())
        location_field = "SAMPLE_ID" if kind == "classic" else "SAMPLE_LOC"
        lookup = {row[table.index(location_field)]: row for row in table.rows}
        if len(lookup) != len(definition["cells"]):
            raise ValueError("Reference source locations do not cover the structural grid")
        cells = []
        for cell in definition["cells"]:
            location = cell["sourceLocation"]
            # Structural Classic locations omit the zero in the .cie table.
            if kind == "classic":
                location = f"{location[0]}{int(location[1:]):02d}"
            row = lookup[location]
            values = [float(row[table.index(field)]) for field in fields]
            xyz = list(lab_to_xyz(values, white)) if kind == "classic" else values
            cells.append({"sourceLocation": cell["sourceLocation"], "available": kind == "classic",
                          "XYZ": xyz, "reason": "" if kind == "classic" else
                          "The original SG expected XYZ has no established illuminant, observer or reference white. Reference color is unavailable.",
                          "originalValues": values})
        data = {
            "format": "chart-reference-illustrations", "version": 1,
            "definitionId": definition["id"], "definitionRevision": definition["revision"],
            "cells": cells,
            "context": {"observerId": "CIE1931_2deg", "xyzUnits": "1",
                        "xyzScale": "relative; perfect-diffuser Y=100", "whiteXYZ": white,
                        "illuminant": "D50", "interpretation": "Argyll D50/1931 expected-color convention"} if kind == "classic" else {},
            "provenance": {
                "source": f"ArgyllCMS 3.5.0 {relative}", "sourceSHA256": PINS[relative],
                "created": table.keywords["CREATED"], "originalFields": list(fields),
                "originalFile": f"resources/charts/sources/{Path(relative).name}",
                "edition": "Historical reference; physical chart edition unverified",
                "conditions": ("Source has no explicit illuminant/observer keywords; interpreted using the pinned Classic Lab consumer convention, not specimen measurement conditions" if kind == "classic" else "The original SG XYZ illuminant, observer and white are unestablished; reference rendering is unavailable"),
                "historicalConsumerConvention": ("Argyll scanin converts the Classic Lab table with ICC D50/1931" if kind == "classic" else "Argyll chartread compares expected XYZ/100 as D50 Lab; this does not establish the original SG XYZ illuminant, observer or white"),
                "meaning": ("Approximate expected reference illustration; not a measured specimen, accuracy standard or position-test reference" if kind == "classic" else "Original expected XYZ retained without reference rendering; not a measured specimen, accuracy standard or position-test reference"),
                "terms": "AGPL-3.0; resources/charts/ARGYLL-AGPL-3.0.txt",
            },
        }
        result[f"resources/charts/{kind}-reference.json"] = encode(data)
        result[data["provenance"]["originalFile"]] = original[relative]
    manifest = {
        "format": "chart-reference-sources", "version": 1,
        "generator": {"path": "tools/charts/generateReferences.py", "sha256": digest(Path(__file__).read_bytes())},
        "upstream": {"release": "ArgyllCMS 3.5.0", "archive": "https://www.argyllcms.com/Argyll_V3.5.0_src.zip",
                     "archiveSHA256": "f8576ce5589fd15620abb73ff049ea31f55ddbd1bba6d1ffa87452658e7bc85f",
                     "files": [{"path": name, "sha256": value} for name, value in PINS.items()]},
        "interpretation": {
            "classic": "scanin/scanin.c:1403-1408 converts .cie Lab using icmD50, then scales XYZ by 100",
            "sg": "spectro/chartread.c:193 defines expected eXYZ on scale 100; :3128-3132 reads ti2 expected XYZ; :149-163 computes D50 Lab from XYZ/100. This consumer convention does not establish this source table basis; SG reference display is unavailable.",
            "whiteAndObserver": "icc/icc_util.c:2080-2095 states 1931 observer and defines ICC-rounded D50 and D50*100",
            "notEstablished": "Physical chart edition, specimen spectral reflectance, backing, geometry, measurement condition and reference accuracy",
        },
        "buildDependencies": [{"module": module.__name__, "sha256": digest(Path(module.__file__).read_bytes())}
                              for module in (cgats, science)],
        "sourceTerms": {"license": "AGPL-3.0", "path": "resources/charts/ARGYLL-AGPL-3.0.txt", "sha256": PINS["ref/License.txt"]},
        "redistributionStatus": "Local copies authorized; external distribution not cleared; retain original data, source manifest and AGPL terms",
        "files": [{"path": path, "sha256": digest(raw)} for path, raw in result.items()],
    }
    result["resources/provenance/chart-reference-source.json"] = encode(manifest)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--argyll-source", type=Path, required=True)
    parser.add_argument("--python-project", type=Path, required=True, help="Project containing the existing CGATS/science modules; generation only")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    files = outputs(args.argyll_source, args.python_project)
    helper = ROOT / "src/+colormeasure/+chart/referenceData.m"
    original = helper.read_text(encoding="utf-8")
    expected, count = re.subn(r"manifestDigest = '[^']+';", f"manifestDigest = '{digest(files['resources/provenance/chart-reference-source.json'])}';", original)
    if count != 1:
        raise SystemExit("Reference manifest digest anchor is missing or ambiguous")
    if args.check:
        stale = [path for path, raw in files.items() if not (ROOT / path).is_file() or (ROOT / path).read_bytes() != raw]
        if original != expected:
            stale.append(str(helper.relative_to(ROOT)))
        if stale:
            raise SystemExit("Reference illustrations differ: " + ", ".join(stale))
        print("Classic 24 illustrations and SG 140 unavailable reference entries reproduce exactly.")
    else:
        for path, raw in files.items():
            target = ROOT / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        helper.write_text(expected, encoding="utf-8")
        print("Generated historical references, original numerical sources and manifest.")


if __name__ == "__main__":
    main()
